import Foundation

enum ReviewGrade {
    case gotIt
    case again
}

/// Pure scheduling logic: no SwiftData, no UI, easy to test.
/// Stage i means "wait intervalDays[i] days before the next review".
enum ReviewScheduler {
    static let intervalDays = [1, 3, 7]
    static var graduatedStage: Int { intervalDays.count }

    struct Schedule: Equatable {
        let stage: Int
        let nextReviewAt: Date
    }

    static func initial(now: Date, calendar: Calendar = .current) -> Schedule {
        Schedule(stage: 0, nextReviewAt: date(after: intervalDays[0], from: now, calendar: calendar))
    }

    static func review(stage: Int, grade: ReviewGrade, now: Date, calendar: Calendar = .current) -> Schedule {
        switch grade {
        case .again:
            return initial(now: now, calendar: calendar)
        case .gotIt:
            let next = stage + 1
            guard next < intervalDays.count else {
                return Schedule(stage: graduatedStage, nextReviewAt: .distantFuture)
            }
            return Schedule(stage: next, nextReviewAt: date(after: intervalDays[next], from: now, calendar: calendar))
        }
    }

    private static func date(after days: Int, from now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: now) ?? now
    }
}
