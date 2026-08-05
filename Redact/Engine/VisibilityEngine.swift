import Foundation

struct VisibilityEngine {

    /// Computes visibility for all paragraphs based on the active paragraph and settings.
    /// `paragraphLengths` carries one character count per paragraph, in document order;
    /// partial masking needs the length to cover the whole paragraph, not a fixed prefix.
    func computeVisibility(
        paragraphLengths: [Int],
        activeParagraphIndex: Int,
        fullVisible: Int,
        partialVisible: Int,
        documentSeed: UUID
    ) -> [RedactionState.ParagraphState] {
        let paragraphCount = paragraphLengths.count
        guard paragraphCount > 0 else { return [] }

        let active = min(activeParagraphIndex, paragraphCount - 1)
        let visibleStart = max(0, active - fullVisible + 1)
        let partialStart = max(0, visibleStart - partialVisible)

        return (0..<paragraphCount).map { i in
            let visibility: RedactionState.VisibilityLevel
            let partialIndices: [Int]

            if i >= visibleStart && i <= active {
                visibility = .visible
                partialIndices = []
            } else if i >= partialStart && i < visibleStart {
                visibility = .partial
                partialIndices = computePartialIndices(
                    paragraphIndex: i,
                    seed: documentSeed,
                    paragraphLength: paragraphLengths[i]
                )
            } else {
                visibility = .redacted
                partialIndices = []
            }

            return RedactionState.ParagraphState(
                index: i,
                visibility: visibility,
                partiallyVisibleIndices: partialIndices
            )
        }
    }

    /// Returns only paragraphs whose visibility changed between previous and current state.
    func visibilityChanges(
        previous: [RedactionState.ParagraphState],
        current: [RedactionState.ParagraphState]
    ) -> [(index: Int, from: RedactionState.VisibilityLevel, to: RedactionState.VisibilityLevel)] {
        var changes: [(index: Int, from: RedactionState.VisibilityLevel, to: RedactionState.VisibilityLevel)] = []

        for state in current {
            let previousVisibility = previous.first(where: { $0.index == state.index })?.visibility
            let from = previousVisibility ?? .visible
            if from != state.visibility {
                changes.append((index: state.index, from: from, to: state.visibility))
            }
        }

        return changes
    }

    /// Selects ~50% of a paragraph's characters to leave visible, deterministically.
    ///
    /// The selection must be identical for a given (document, paragraph) forever — the same
    /// characters stay hidden across relaunches, reinstalls, and devices. That rules out
    /// `Hasher`, which Swift seeds randomly per process.
    private func computePartialIndices(paragraphIndex: Int, seed: UUID, paragraphLength: Int) -> [Int] {
        guard paragraphLength > 0 else { return [] }

        var rng = SplitMix64(seed: Self.deterministicSeed(documentSeed: seed, paragraphIndex: paragraphIndex))
        var indices: [Int] = []
        indices.reserveCapacity(paragraphLength / 2)

        for index in 0..<paragraphLength {
            if rng.next().isMultiple(of: 2) {
                indices.append(index)
            }
        }
        return indices
    }

    /// FNV-1a over the document UUID's 16 raw bytes plus the paragraph index.
    /// Stable across processes, platforms, and Swift versions.
    private static func deterministicSeed(documentSeed: UUID, paragraphIndex: Int) -> UInt64 {
        let prime: UInt64 = 0x0000_0100_0000_01B3
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325  // FNV-1a 64-bit offset basis

        withUnsafeBytes(of: documentSeed.uuid) { bytes in
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* prime
            }
        }
        withUnsafeBytes(of: UInt64(bitPattern: Int64(paragraphIndex)).littleEndian) { bytes in
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* prime
            }
        }
        return hash
    }
}

/// Deterministic pseudo-random generator (SplitMix64).
///
/// Swift's `Hasher` is randomly seeded per process, so a mask derived from it reshuffles on
/// every app launch. This generator depends only on its seed, which is what lets partial
/// redaction keep the same characters hidden for the life of a document.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
