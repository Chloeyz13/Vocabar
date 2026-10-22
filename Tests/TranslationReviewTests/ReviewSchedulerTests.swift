import XCTest
@testable import TranslationReview

final class ReviewSchedulerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func days(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: n, to: now)!
    }

    func testNewCardIsDueInOneDay() {
        let schedule = ReviewScheduler.initial(now: now, calendar: calendar)
        XCTAssertEqual(schedule.stage, 0)
        XCTAssertEqual(schedule.nextReviewAt, days(1))
    }

    func testGotItAdvancesThroughIntervals() {
        let second = ReviewScheduler.review(stage: 0, grade: .gotIt, now: now, calendar: calendar)
        XCTAssertEqual(second.stage, 1)
        XCTAssertEqual(second.nextReviewAt, days(3))

        let third = ReviewScheduler.review(stage: 1, grade: .gotIt, now: now, calendar: calendar)
        XCTAssertEqual(third.stage, 2)
        XCTAssertEqual(third.nextReviewAt, days(7))
    }

    func testGotItAfterLastStageGraduates() {
        let done = ReviewScheduler.review(stage: 2, grade: .gotIt, now: now, calendar: calendar)
        XCTAssertEqual(done.stage, ReviewScheduler.graduatedStage)
        XCTAssertEqual(done.nextReviewAt, .distantFuture)
    }

    func testAgainResetsToStageZero() {
        let reset = ReviewScheduler.review(stage: 2, grade: .again, now: now, calendar: calendar)
        XCTAssertEqual(reset.stage, 0)
        XCTAssertEqual(reset.nextReviewAt, days(1))
    }
}
