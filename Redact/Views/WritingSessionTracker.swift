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

    /// Adopts the timing of a session that began in an earlier launch.
    ///
    /// The tracker starts empty on every launch and only begins timing at the first
    /// keystroke, so a document reopened after a force-quit reported a duration of zero
    /// — and with it a WPM of zero — no matter how long it actually took to write. The
    /// document already persists both dates; this is the seam that puts them back.
    ///
    /// Deliberately does nothing once a session is under way, so returning to a
    /// document mid-session cannot rewind its own start.
    func resume(startedAt: Date, lastActivityAt: Date) {
        guard sessionStartDate == nil else { return }
        guard lastActivityAt >= startedAt else { return }

        sessionStartDate = startedAt
        lastKeystrokeDate = lastActivityAt
        currentStreakStart = lastActivityAt
    }

    func reset() {
        sessionStartDate = nil
        lastKeystrokeDate = nil
        currentStreakStart = nil
        longestStreakSeconds = 0
    }
}
