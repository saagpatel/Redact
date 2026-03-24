import Foundation

struct VisibilityEngine {

    /// Computes visibility for all paragraphs based on the active paragraph and settings.
    func computeVisibility(
        paragraphCount: Int,
        activeParagraphIndex: Int,
        fullVisible: Int,
        partialVisible: Int,
        documentSeed: UUID
    ) -> [RedactionState.ParagraphState] {
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
                partialIndices = computePartialIndices(paragraphIndex: i, seed: documentSeed)
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

    private func computePartialIndices(paragraphIndex: Int, seed: UUID) -> [Int] {
        var hasher = Hasher()
        hasher.combine(seed)
        hasher.combine(paragraphIndex)
        let seedValue = abs(hasher.finalize())

        var indices: [Int] = []
        for i in 0..<100 {
            var h = Hasher()
            h.combine(seedValue)
            h.combine(i)
            if abs(h.finalize()) % 2 == 0 {
                indices.append(i)
            }
        }
        return indices
    }
}
