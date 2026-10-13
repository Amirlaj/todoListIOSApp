import Foundation
import SwiftData

/// A CSV or Markdown file that was imported into a chapter. Deleting it deletes its cards.
@Model
final class SourceFile {
    var fileName: String = ""
    var kindRaw: String = SourceKind.markdown.rawValue
    var importedAt: Date = Date.now
    var chapter: Chapter?

    @Relationship(deleteRule: .cascade, inverse: \Flashcard.sourceFile)
    var cards: [Flashcard] = []

    init(fileName: String, kind: SourceKind) {
        self.fileName = fileName
        self.kindRaw = kind.rawValue
        self.importedAt = .now
    }
}

extension SourceFile {
    var kind: SourceKind {
        SourceKind(rawValue: kindRaw) ?? .markdown
    }
}
