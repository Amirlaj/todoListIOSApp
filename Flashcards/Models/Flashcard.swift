import Foundation
import SwiftData

/// A single question/answer card. Study progress uses a simple Leitner box:
/// "Got it" moves the card up one box, "Again" sends it back to box 0.
@Model
final class Flashcard {
    var front: String = ""
    var back: String = ""
    var sortIndex: Int = 0
    var createdAt: Date = Date.now

    var box: Int = 0
    var timesCorrect: Int = 0
    var timesIncorrect: Int = 0
    var lastReviewedAt: Date?
    var dueAt: Date?
    var isFavorite: Bool = false
    var tagText: String = ""

    @Relationship(deleteRule: .cascade, inverse: \ReviewRecord.card)
    var reviews: [ReviewRecord]? = []

    var chapter: Chapter?
    /// The file this card was imported from, or nil for cards added by hand.
    var sourceFile: SourceFile?

    init(front: String, back: String, sortIndex: Int) {
        self.front = front
        self.back = back
        self.sortIndex = sortIndex
        self.createdAt = .now
    }
}

enum CardStatus {
    case new
    case learning
    case mastered
}

extension Flashcard {
    static let maxBox = 5
    static let masteredBox = 3

    var isMastered: Bool { box >= Flashcard.masteredBox }

    var status: CardStatus {
        if isMastered { return .mastered }
        return lastReviewedAt == nil ? .new : .learning
    }

    var tags: [String] { CardTags.parse(tagText) }
    var reviewList: [ReviewRecord] { reviews ?? [] }

    func isDue(at date: Date = .now) -> Bool {
        (dueAt ?? .distantPast) <= date
    }

    func recordReview(correct: Bool, at date: Date = .now) {
        if correct {
            box = min(box + 1, Flashcard.maxBox)
            timesCorrect += 1
        } else {
            box = 0
            timesIncorrect += 1
        }
        lastReviewedAt = date
        dueAt = ReviewSchedule.nextDate(box: box, after: date)
    }

    func resetProgress() {
        box = 0
        timesCorrect = 0
        timesIncorrect = 0
        lastReviewedAt = nil
        dueAt = nil
    }
}
