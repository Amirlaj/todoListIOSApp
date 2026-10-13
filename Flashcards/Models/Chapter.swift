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
    var cards: [Flashcard] = []

    @Relationship(deleteRule: .cascade, inverse: \SourceFile.chapter)
    var sourceFiles: [SourceFile] = []

    init(name: String, sortIndex: Int) {
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = .now
    }
}

extension Chapter {
    var sortedCards: [Flashcard] {
        cards.sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    var sortedSourceFiles: [SourceFile] {
        sourceFiles.sorted { $0.importedAt < $1.importedAt }
    }

    var nextCardIndex: Int {
        (cards.map(\.sortIndex).max() ?? -1) + 1
    }

    var masteredCount: Int { cards.filter(\.isMastered).count }
    var newCount: Int { cards.filter { $0.status == .new }.count }
    var learningCount: Int { cards.filter { $0.status == .learning }.count }

    var progress: Double {
        cards.isEmpty ? 0 : Double(masteredCount) / Double(cards.count)
    }

    /// Keys of the existing cards, used to flag duplicates when importing.
    var duplicateKeys: Set<String> {
        Set(cards.map { ParsedCard(front: $0.front, back: $0.back).duplicateKey })
    }
}
