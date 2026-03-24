import Foundation

struct WritingStats: Codable, Equatable {
    let wordCount: Int
    let paragraphCount: Int
    let durationSeconds: TimeInterval       // first keystroke → Done tap
    let wordsPerMinute: Double              // wordCount / (durationSeconds / 60)
    let longestStreakSeconds: TimeInterval   // longest uninterrupted typing (no pause > 30s)
}
