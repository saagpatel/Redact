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
}
