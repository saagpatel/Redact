import Foundation

struct Document: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String                       // Auto: first 5 words of first paragraph. Editable post-reveal.
    var rawText: String                     // Full plain text content
    var redactionState: RedactionState      // Per-paragraph visibility — serialized for session restore
    var isComplete: Bool                    // false = in-progress, true = revealed
    var wordCountTarget: Int?              // nil = open-ended
    var createdAt: Date
    var lastModifiedAt: Date
    var revealedAt: Date?                  // nil until revealed
    var stats: WritingStats?               // nil until revealed
}
