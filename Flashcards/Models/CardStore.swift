import Foundation
import SwiftData

/// Creates and deletes flashcards so that relationships and ordering stay consistent.
enum CardStore {
    /// Adds parsed cards to a chapter. When a file name is given, the cards are linked to a
    /// new `SourceFile` so they can be removed together later.
    @discardableResult
    static func addCards(
        _ parsedCards: [ParsedCard],
        to chapter: Chapter,
        fileName: String? = nil,
        kind: SourceKind? = nil,
        in context: ModelContext
    ) -> SourceFile? {
        var sourceFile: SourceFile?
        if let fileName, let kind {
            let existingFiles = chapter.fileList
            let file = SourceFile(fileName: fileName, kind: kind)
            context.insert(file)
            file.chapter = chapter
            chapter.sourceFiles = existingFiles + [file]
            sourceFile = file
        }

        var nextIndex = chapter.nextCardIndex
        for parsed in parsedCards {
            let existingCards = chapter.cardList
            let existingSourceCards = sourceFile?.cardList ?? []
            let card = Flashcard(front: parsed.front, back: parsed.back, sortIndex: nextIndex)
            nextIndex += 1
            context.insert(card)
            card.chapter = chapter
            card.sourceFile = sourceFile
            chapter.cards = existingCards + [card]
            sourceFile?.cards = existingSourceCards + [card]
        }
        return sourceFile
    }

    static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("Failed to save flashcards: \(error)")
        }
    }
}
