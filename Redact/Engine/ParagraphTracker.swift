import UIKit

protocol ParagraphTracking {
    /// Returns array of paragraph NSRanges from NSTextStorage
    func paragraphRanges(in textStorage: NSTextStorage) -> [NSRange]

    /// Returns index of paragraph containing cursorPosition
    func activeParagraphIndex(cursorPosition: Int, paragraphs: [NSRange]) -> Int

    /// Returns true if a new paragraph was just created (current.count > previous.count)
    func didCompleteParagraph(previous: [NSRange], current: [NSRange]) -> Bool
}

final class ParagraphTracker: ParagraphTracking {

    func paragraphRanges(in textStorage: NSTextStorage) -> [NSRange] {
        let string = textStorage.string
        guard !string.isEmpty else { return [] }

        var ranges: [NSRange] = []
        let nsString = string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        nsString.enumerateSubstrings(
            in: fullRange,
            options: .byParagraphs
        ) { _, substringRange, _, _ in
            ranges.append(substringRange)
        }

        return ranges
    }

    func activeParagraphIndex(cursorPosition: Int, paragraphs: [NSRange]) -> Int {
        guard !paragraphs.isEmpty else { return 0 }

        // Reverse search: cursor at a boundary belongs to the next paragraph
        for i in stride(from: paragraphs.count - 1, through: 0, by: -1) {
            let range = paragraphs[i]
            if cursorPosition >= range.location {
                return i
            }
        }

        return 0
    }

    func didCompleteParagraph(previous: [NSRange], current: [NSRange]) -> Bool {
        current.count > previous.count
    }
}
