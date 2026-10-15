import Foundation
import SwiftData

/// A subject (e.g. "Biology") that groups chapters of flashcards.
@Model
final class StudyModule {
    var name: String = ""
    var details: String = ""
    var colorName: String = "blue"
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Chapter.module)
    var chapters: [Chapter]? = []

    init(name: String, details: String = "", colorName: String = "blue") {
        self.name = name
        self.details = details
        self.colorName = colorName
        self.createdAt = .now
    }
}

extension StudyModule {
    var chapterList: [Chapter] { chapters ?? [] }

    var sortedChapters: [Chapter] {
        chapterList.sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    var nextChapterIndex: Int {
        (chapterList.map(\.sortIndex).max() ?? -1) + 1
    }

    /// All cards in the module, in chapter order.
    var allCards: [Flashcard] {
        sortedChapters.flatMap(\.sortedCards)
    }

    var cardCount: Int {
        chapterList.reduce(0) { $0 + $1.cardList.count }
    }

    var masteredCount: Int {
        chapterList.reduce(0) { $0 + $1.masteredCount }
    }

    var progress: Double {
        cardCount == 0 ? 0 : Double(masteredCount) / Double(cardCount)
    }
}
