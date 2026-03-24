import Foundation

struct RedactionState: Codable, Equatable {
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

    var paragraphs: [ParagraphState]
    var activeParagraphIndex: Int
}
