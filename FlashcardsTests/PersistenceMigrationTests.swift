import Foundation
import SwiftData
import Testing
@testable import Flashcards

private enum OriginalSchema {

    @Model
    final class StudyModule {
        var name: String = ""
        var details: String = ""
        var colorName: String = "blue"
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \Chapter.module)
        var chapters: [Chapter] = []

        init(name: String, details: String = "", colorName: String = "blue") {
            self.name = name
            self.details = details
            self.colorName = colorName
            self.createdAt = .now
        }
    }

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
}


@MainActor
struct PersistenceMigrationTests {
    @Test func originalLibraryMigratesWithoutLosingCardsOrRelationships() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("default.store")
        try seedOriginalLibrary(at: url)
        let schema = Schema(AppSchema.models)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let module = try #require(container.mainContext.fetch(FetchDescriptor<StudyModule>()).first)
        #expect(module.name == "Original module")
        let chapter = try #require(module.chapterList.first)
        #expect(chapter.name == "Original chapter")
        let card = try #require(chapter.cardList.first)
        #expect(card.front == "Original question")
        #expect(card.back == "Original answer")
        #expect(card.box == 2)
        #expect(card.sourceFile?.fileName == "notes.md")
        #expect(card.reviewList.isEmpty)
        #expect(!card.isFavorite)
        #expect(card.tags.isEmpty)
        #expect(card.isDue())
    }

    private func seedOriginalLibrary(at url: URL) throws {
        let schema = Schema([OriginalSchema.StudyModule.self, OriginalSchema.Chapter.self, OriginalSchema.Flashcard.self, OriginalSchema.SourceFile.self])
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let module = OriginalSchema.StudyModule(name: "Original module")
        let chapter = OriginalSchema.Chapter(name: "Original chapter", sortIndex: 0)
        let card = OriginalSchema.Flashcard(front: "Original question", back: "Original answer", sortIndex: 0)
        let file = OriginalSchema.SourceFile(fileName: "notes.md", kind: .markdown)
        context.insert(module)
        context.insert(chapter)
        context.insert(card)
        context.insert(file)
        chapter.module = module
        card.chapter = chapter
        card.sourceFile = file
        card.box = 2
        file.chapter = chapter
        try context.save()
    }

}
