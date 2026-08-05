import XCTest
@testable import Redact

@MainActor
final class WritingSessionTrackerTests: XCTestCase {

    func testNoKeystrokesProducesZeroStats() {
        let tracker = WritingSessionTracker()
        let stats = tracker.computeStats(wordCount: 100, paragraphCount: 5)
        XCTAssertEqual(stats.durationSeconds, 0)
        XCTAssertEqual(stats.wordsPerMinute, 0)
        XCTAssertEqual(stats.longestStreakSeconds, 0)
        XCTAssertEqual(stats.wordCount, 100)
        XCTAssertEqual(stats.paragraphCount, 5)
    }

    func testSingleKeystrokeProducesZeroDuration() {
        let currentTime = Date()
        let tracker = WritingSessionTracker(dateProvider: { currentTime })
        tracker.recordKeystroke()
        let stats = tracker.computeStats(wordCount: 1, paragraphCount: 1)
        XCTAssertEqual(stats.durationSeconds, 0)
    }

    func testTwoKeystrokesProducesCorrectDuration() {
        var currentTime = Date()
        let tracker = WritingSessionTracker(dateProvider: { currentTime })
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(60)
        tracker.recordKeystroke()
        let stats = tracker.computeStats(wordCount: 10, paragraphCount: 1)
        XCTAssertEqual(stats.durationSeconds, 60, accuracy: 0.01)
        XCTAssertEqual(stats.wordsPerMinute, 10, accuracy: 0.01)
    }

    func testStreakBrokenByPause() {
        var currentTime = Date()
        let tracker = WritingSessionTracker(dateProvider: { currentTime })
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(10)
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(10)
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(35)
        tracker.recordKeystroke()
        let stats = tracker.computeStats(wordCount: 10, paragraphCount: 1)
        XCTAssertEqual(stats.longestStreakSeconds, 20, accuracy: 0.01)
    }

    func testStreakNotBrokenAtExactThreshold() {
        var currentTime = Date()
        let tracker = WritingSessionTracker(dateProvider: { currentTime })
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(30)
        tracker.recordKeystroke()
        let stats = tracker.computeStats(wordCount: 10, paragraphCount: 1)
        XCTAssertEqual(stats.longestStreakSeconds, 30, accuracy: 0.01)
    }

    func testMultipleStreaksTracksLongest() {
        var currentTime = Date()
        let tracker = WritingSessionTracker(dateProvider: { currentTime })
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(10)
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(10)
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(35)
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(10)
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(10)
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(10)
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(5)
        tracker.recordKeystroke()
        let stats = tracker.computeStats(wordCount: 10, paragraphCount: 1)
        XCTAssertEqual(stats.longestStreakSeconds, 35, accuracy: 0.01)
    }

    func testResetClearsAllState() {
        var currentTime = Date()
        let tracker = WritingSessionTracker(dateProvider: { currentTime })
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(60)
        tracker.recordKeystroke()
        tracker.reset()
        let stats = tracker.computeStats(wordCount: 0, paragraphCount: 0)
        XCTAssertEqual(stats.durationSeconds, 0)
        XCTAssertEqual(stats.longestStreakSeconds, 0)
        XCTAssertNil(tracker.sessionStartDate)
        XCTAssertNil(tracker.lastKeystrokeDate)
    }

    func testComputeStatsPassesThroughWordCountAndParagraphCount() {
        let tracker = WritingSessionTracker()
        let stats = tracker.computeStats(wordCount: 247, paragraphCount: 12)
        XCTAssertEqual(stats.wordCount, 247)
        XCTAssertEqual(stats.paragraphCount, 12)
    }

    func testTotalDurationSpansEntireSession() {
        var currentTime = Date()
        let tracker = WritingSessionTracker(dateProvider: { currentTime })
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(100)
        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(200)
        tracker.recordKeystroke()
        let stats = tracker.computeStats(wordCount: 50, paragraphCount: 3)
        XCTAssertEqual(stats.durationSeconds, 300, accuracy: 0.01)
    }

    // MARK: - Resuming a session from an earlier launch

    /// The bug this guards: the tracker is rebuilt on every launch and only starts
    /// timing at the first keystroke, so a document reopened after a force-quit and
    /// finished reported 0m 0s and 0 WPM regardless of how long it took to write.
    func testResumedSessionReportsTheDurationFromTheEarlierLaunch() {
        let start = Date()
        let currentTime = start.addingTimeInterval(1_200)  // reopened 20 minutes later
        let tracker = WritingSessionTracker(dateProvider: { currentTime })

        tracker.resume(startedAt: start, lastActivityAt: start.addingTimeInterval(1_140))

        let stats = tracker.computeStats(wordCount: 400, paragraphCount: 6)
        XCTAssertEqual(stats.durationSeconds, 1_140, accuracy: 0.01)
        XCTAssertGreaterThan(stats.wordsPerMinute, 0)

    }

    func testKeystrokesAfterResumingExtendTheOriginalSession() {
        let start = Date()
        var currentTime = start.addingTimeInterval(600)
        let tracker = WritingSessionTracker(dateProvider: { currentTime })

        tracker.resume(startedAt: start, lastActivityAt: start.addingTimeInterval(540))
        currentTime = start.addingTimeInterval(660)
        tracker.recordKeystroke()

        // Measured from the original start, not from the relaunch.
        XCTAssertEqual(
            tracker.computeStats(wordCount: 100, paragraphCount: 2).durationSeconds,
            660,
            accuracy: 0.01
        )
    }

    func testResumeDoesNotRewindASessionAlreadyUnderWay() {
        var currentTime = Date()
        let tracker = WritingSessionTracker(dateProvider: { currentTime })

        tracker.recordKeystroke()
        currentTime = currentTime.addingTimeInterval(60)
        tracker.recordKeystroke()

        // Returning to a document mid-session must not adopt an older start date.
        tracker.resume(
            startedAt: currentTime.addingTimeInterval(-9_999),
            lastActivityAt: currentTime
        )

        XCTAssertEqual(
            tracker.computeStats(wordCount: 20, paragraphCount: 1).durationSeconds,
            60,
            accuracy: 0.01
        )
    }

    func testResumeIgnoresIncoherentDates() {
        let now = Date()
        let currentTime = now
        let tracker = WritingSessionTracker(dateProvider: { currentTime })

        // lastActivity before start would yield a negative duration.
        tracker.resume(startedAt: now, lastActivityAt: now.addingTimeInterval(-500))

        XCTAssertEqual(tracker.computeStats(wordCount: 10, paragraphCount: 1).durationSeconds, 0)
    }
}
