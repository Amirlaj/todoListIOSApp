import Foundation
import SwiftData

/// A chapter inside a module. Its flashcards come from imported files or are added by hand.
@Model
final class Chapter {
    var name: String = ""
    var sortIndex: Int = 0
    var createdAt: Date = Date.now
    var module: StudyModule?

    @Relationship(deleteRule: .cascade, inverse: \Flashcard.chapter)
    var cards: [Flashcard]? = []

    @Relationship(deleteRule: .cascade, inverse: \SourceFile.chapter)
    var sourceFiles: [SourceFile]? = []

    init(name: String, sortIndex: Int) {
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = .now
    }
}

extension Chapter {
    var cardList: [Flashcard] { cards ?? [] }
    var fileList: [SourceFile] { sourceFiles ?? [] }

    var sortedCards: [Flashcard] {
        cardList.sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    var sortedSourceFiles: [SourceFile] {
        fileList.sorted { $0.importedAt < $1.importedAt }
    }

    var nextCardIndex: Int {
        (cardList.map(\.sortIndex).max() ?? -1) + 1
    }

    var masteredCount: Int { cardList.filter(\.isMastered).count }
    var newCount: Int { cardList.filter { $0.status == .new }.count }
    var learningCount: Int { cardList.filter { $0.status == .learning }.count }

    var progress: Double {
        cardList.isEmpty ? 0 : Double(masteredCount) / Double(cardList.count)
    }

    /// Keys of the existing cards, used to flag duplicates when importing.
    var duplicateKeys: Set<String> {
        Set(cardList.map { ParsedCard(front: $0.front, back: $0.back).duplicateKey })
    }
}
