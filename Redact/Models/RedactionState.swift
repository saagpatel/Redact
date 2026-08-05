import Foundation

struct RedactionState: Codable, Equatable {

    /// Persisted format version.
    ///
    /// 1 — pre-deterministic masking. `partiallyVisibleIndices` was seeded from `Hasher`, so it
    ///     changed on every app launch, and it never addressed a character past index 99.
    /// 2 — deterministic, whole-paragraph masking.
    ///
    /// Session restore regenerates masks from the document seed rather than replaying what was
    /// stored, so a version 1 document renders correctly without a migration. The field earns
    /// its place going the other way: a state written by a newer build is refused rather than
    /// silently misread by an older one, which is the failure a version-less format cannot
    /// detect.
    static let currentSchemaVersion = 2

    struct ParagraphState: Codable, Equatable {
        let index: Int
        let visibility: VisibilityLevel
        let partiallyVisibleIndices: [Int]
    }

    enum VisibilityLevel: String, Codable {
        case visible    // current + previous paragraph — 100% shown
        case partial    // ~50% of chars visible, seeded from document.id
        case redacted   // fully hidden, 100% covered
    }

    var schemaVersion: Int
    var paragraphs: [ParagraphState]
    var activeParagraphIndex: Int

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case paragraphs
        case activeParagraphIndex
    }

    init(
        paragraphs: [ParagraphState],
        activeParagraphIndex: Int,
        schemaVersion: Int = RedactionState.currentSchemaVersion
    ) {
        self.paragraphs = paragraphs
        self.activeParagraphIndex = activeParagraphIndex
        self.schemaVersion = schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Absent means version 1: the field did not exist before deterministic masking.
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1

        guard version <= Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: """
                    RedactionState schema version \(version) was written by a newer build than \
                    this one, which understands up to \(Self.currentSchemaVersion). Refusing to \
                    guess at the meaning of its fields.
                    """
            )
        }

        schemaVersion = version
        paragraphs = try container.decode([ParagraphState].self, forKey: .paragraphs)
        activeParagraphIndex = try container.decode(Int.self, forKey: .activeParagraphIndex)
    }
}
