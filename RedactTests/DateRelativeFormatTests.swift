import XCTest
@testable import Redact

/// Coverage for `Date.relativeDisplay`, the timestamp shown on every row of the document list.
///
/// The tests anchor every fixture at noon rather than using `Date()` directly, so a run that
/// straddles midnight cannot flip a date into the wrong bucket. For the fallback branch they
/// compare against a formatter built the same way as the implementation rather than a literal
/// string, so the suite does not fail on a simulator with a non-English locale.
final class DateRelativeFormatTests: XCTestCase {

    private let calendar = Calendar.current

    /// Noon on the day `dayOffset` days from today, in the current calendar.
    private func noon(daysFromToday dayOffset: Int) throws -> Date {
        let startOfToday = calendar.startOfDay(for: Date())
        let day = try XCTUnwrap(calendar.date(byAdding: .day, value: dayOffset, to: startOfToday))
        return try XCTUnwrap(calendar.date(byAdding: .hour, value: 12, to: day))
    }

    private func expectedFallbackString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // MARK: - Today

    func testTodayReadsAsToday() throws {
        XCTAssertEqual(try noon(daysFromToday: 0).relativeDisplay, "Today")
    }

    func testStartOfTodayReadsAsToday() {
        XCTAssertEqual(calendar.startOfDay(for: Date()).relativeDisplay, "Today")
    }

    func testNowReadsAsToday() {
        XCTAssertEqual(Date().relativeDisplay, "Today")
    }

    func testLastMomentOfTodayReadsAsToday() throws {
        let startOfTomorrow = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
        )
        let lastMoment = startOfTomorrow.addingTimeInterval(-1)
        XCTAssertEqual(lastMoment.relativeDisplay, "Today")
    }

    // MARK: - Yesterday

    func testYesterdayReadsAsYesterday() throws {
        XCTAssertEqual(try noon(daysFromToday: -1).relativeDisplay, "Yesterday")
    }

    func testFirstMomentOfYesterdayReadsAsYesterday() throws {
        let startOfYesterday = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))
        )
        XCTAssertEqual(startOfYesterday.relativeDisplay, "Yesterday")
    }

    // MARK: - Older dates fall back to a formatted date

    func testTwoDaysAgoFallsBackToAFormattedDate() throws {
        let date = try noon(daysFromToday: -2)
        let display = date.relativeDisplay

        XCTAssertNotEqual(display, "Today")
        XCTAssertNotEqual(display, "Yesterday")
        XCTAssertEqual(display, expectedFallbackString(for: date))
    }

    func testDateLastMonthFallsBackToAFormattedDate() throws {
        let date = try noon(daysFromToday: -40)
        XCTAssertEqual(date.relativeDisplay, expectedFallbackString(for: date))
    }

    func testDateLastYearFallsBackToAFormattedDate() throws {
        let date = try noon(daysFromToday: -400)
        let display = date.relativeDisplay

        XCTAssertEqual(display, expectedFallbackString(for: date))
        XCTAssertNotEqual(display, "Today")
        XCTAssertNotEqual(display, "Yesterday")
    }

    // MARK: - Future dates

    func testTomorrowFallsBackToAFormattedDate() throws {
        // Not reachable by writing, but a device clock change can produce it. Documents that
        // future dates take the fallback branch rather than reading as "Today".
        let date = try noon(daysFromToday: 1)
        let display = date.relativeDisplay

        XCTAssertNotEqual(display, "Today")
        XCTAssertNotEqual(display, "Yesterday")
        XCTAssertEqual(display, expectedFallbackString(for: date))
    }

    // MARK: - Stability

    func testDisplayIsStableAcrossRepeatedCalls() throws {
        let date = try noon(daysFromToday: -5)
        XCTAssertEqual(date.relativeDisplay, date.relativeDisplay)
    }

    func testDistinctOlderDaysProduceDistinctDisplays() throws {
        let earlier = try noon(daysFromToday: -5)
        let later = try noon(daysFromToday: -4)
        XCTAssertNotEqual(earlier.relativeDisplay, later.relativeDisplay)
    }
}
