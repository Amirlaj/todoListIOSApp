import Foundation
import SwiftData

@MainActor
enum StudyStore {
    static func review(_ card: Flashcard, correct: Bool, at date: Date = .now, in context: ModelContext) throws {
        try context.save()
        card.recordReview(correct: correct, at: date)
        let record = ReviewRecord(reviewedAt: date, wasCorrect: correct)
        context.insert(record)
        record.card = card
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
