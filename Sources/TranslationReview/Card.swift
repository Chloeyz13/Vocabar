import Foundation
import SwiftData

@Model
final class Card {
    var id: UUID
    var sourceText: String
    var translation: String
    var pronunciation: String?
    var createdAt: Date
    var stage: Int
    var nextReviewAt: Date

    init(sourceText: String, translation: String, pronunciation: String? = nil, now: Date = .now) {
        self.id = UUID()
        self.sourceText = sourceText
        self.translation = translation
        self.pronunciation = pronunciation
        self.createdAt = now
        let schedule = ReviewScheduler.initial(now: now)
        self.stage = schedule.stage
        self.nextReviewAt = schedule.nextReviewAt
    }

    func isDue(at now: Date = .now) -> Bool {
        stage < ReviewScheduler.graduatedStage && nextReviewAt <= now
    }

    func review(_ grade: ReviewGrade, now: Date = .now) {
        let schedule = ReviewScheduler.review(stage: stage, grade: grade, now: now)
        stage = schedule.stage
        nextReviewAt = schedule.nextReviewAt
    }
}
