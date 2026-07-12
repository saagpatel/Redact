import Foundation

@MainActor
final class WritingSessionTracker: ObservableObject {

    private let dateProvider: () -> Date
    private let pauseThreshold: TimeInterval = 30

    private(set) var sessionStartDate: Date?
    private(set) var lastKeystrokeDate: Date?
    private var currentStreakStart: Date?
    private(set) var longestStreakSeconds: TimeInterval = 0

    init(dateProvider: @escaping () -> Date = { Date() }) {
        self.dateProvider = dateProvider
    }

    func recordKeystroke() {
        let now = dateProvider()

        if sessionStartDate == nil {
            sessionStartDate = now
            currentStreakStart = now
        }

        if let lastDate = lastKeystrokeDate {
            let gap = now.timeIntervalSince(lastDate)
            if gap > pauseThreshold {
                if let streakStart = currentStreakStart {
                    let streakDuration = lastDate.timeIntervalSince(streakStart)
                    longestStreakSeconds = max(longestStreakSeconds, streakDuration)
                }
                currentStreakStart = now
            }
        }

        lastKeystrokeDate = now
    }

    func computeStats(wordCount: Int, paragraphCount: Int) -> WritingStats {
        if let streakStart = currentStreakStart, let lastDate = lastKeystrokeDate {
            let streakDuration = lastDate.timeIntervalSince(streakStart)
            longestStreakSeconds = max(longestStreakSeconds, streakDuration)
        }

        let duration: TimeInterval
        if let start = sessionStartDate, let end = lastKeystrokeDate {
            duration = end.timeIntervalSince(start)
        } else {
            duration = 0
        }

        let wpm = duration > 0 ? Double(wordCount) / (duration / 60.0) : 0

        return WritingStats(
            wordCount: wordCount,
            paragraphCount: paragraphCount,
            durationSeconds: duration,
            wordsPerMinute: wpm,
            longestStreakSeconds: longestStreakSeconds
        )
    }

    func reset() {
        sessionStartDate = nil
        lastKeystrokeDate = nil
        currentStreakStart = nil
        longestStreakSeconds = 0
    }
}
