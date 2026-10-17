import Foundation
import SwiftData
import Testing
@testable import Flashcards

@MainActor
struct SampleDataTests {
    private func container() throws -> ModelContainer {
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none),
        ])
    }

    @Test func bundledCourseContainsFiveCompleteWeeksAndRoundTripsThroughCSV() throws {
        let content = try SampleData.load()
        #expect(content.name == "Theory of Computation")
        #expect(content.weeks.map { $0.cards.count } == [36, 36, 36, 42, 42])
        for (index, week) in content.weeks.enumerated() {
            #expect(week.name.hasPrefix("Week \(index + 1):"))
            #expect(!week.sources.isEmpty)
            #expect(week.cards.allSatisfy { !$0.front.trimmed.isEmpty && !$0.back.trimmed.isEmpty })
            #expect(Set(week.parsedCards.map(\.duplicateKey)).count == week.cards.count)
        }
        let store = try container()
        let module = try SampleData.insertSampleModule(into: store.mainContext)
        #expect(module.cardCount == 192)
        #expect(module.sortedChapters.count == 5)
        #expect(module.allCards.allSatisfy { $0.box == 0 && $0.lastReviewedAt == nil && $0.isDue() })
        for (index, chapter) in module.sortedChapters.enumerated() {
            #expect(chapter.fileList.count == 1)
            #expect(chapter.fileList.first?.cardList.count == chapter.cardList.count)
            #expect(chapter.cardList.allSatisfy { $0.tags.contains("week \(index + 1)") })
            let archive = ChapterTransfer.archive(chapter)
            let document = try ChapterDocument(archive: archive, asCSV: true)
            let parsed = FlashcardImporter.parse(text: try FlashcardImporter.decodeText(document.data), fileName: "week.csv")
            #expect(parsed.cards == content.weeks[index].parsedCards)
            #expect(parsed.errorMessage == nil)
        }
        let saved = ModelContext(store)
        #expect(try saved.fetchCount(FetchDescriptor<Flashcard>()) == 192)
        #expect(try saved.fetchCount(FetchDescriptor<SourceFile>()) == 5)
    }

    @Test func addingSampleAgainDoesNotDuplicateOrResetStudyProgress() throws {
        let store = try container()
        let first = try SampleData.insertSampleModule(into: store.mainContext)
        let card = try #require(first.allCards.first)
        try StudyStore.review(card, correct: true, in: store.mainContext)
        let second = try SampleData.insertSampleModule(into: store.mainContext)
        #expect(first === second)
        #expect(card.timesCorrect == 1)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<StudyModule>()) == 1)
    }

    @Test func exactLegacySampleIsReplacedOnceAndPersonalModulesSurvive() throws {
        let store = try container()
        let context = store.mainContext
        makeLegacy(in: context)
        let personal = StudyModule(name: "My notes")
        context.insert(personal)
        try context.save()
        try SampleData.replaceLegacySampleIfNeeded(in: context)
        try SampleData.replaceLegacySampleIfNeeded(in: context)
        let modules = try context.fetch(FetchDescriptor<StudyModule>())
        #expect(Set(modules.map(\.name)) == ["My notes", "Theory of Computation"])
        #expect(try context.fetchCount(FetchDescriptor<Flashcard>()) == 192)
        #expect(try context.fetchCount(FetchDescriptor<SourceFile>()) == 5)
    }

    @Test func editedLegacySampleIsPreserved() throws {
        let store = try container()
        let original = makeLegacy(in: store.mainContext)
        original.allCards[0].back = "My personal answer"
        try store.mainContext.save()
        try SampleData.replaceLegacySampleIfNeeded(in: store.mainContext)
        let modules = try store.mainContext.fetch(FetchDescriptor<StudyModule>())
        #expect(modules.count == 1)
        #expect(modules.first?.name == "Biology (Sample)")
        #expect(original.allCards[0].back == "My personal answer")
    }

    @Test func existingUserModuleWithCourseNameIsPreserved() throws {
        let store = try container()
        let personal = StudyModule(name: "Theory of Computation", details: "My own work")
        store.mainContext.insert(personal)
        try store.mainContext.save()
        let sample = try SampleData.insertSampleModule(into: store.mainContext)
        #expect(sample.name == "Theory of Computation (Sample)")
        #expect(personal.details == "My own work")
        #expect(sample.cardCount == 192)
    }

    @discardableResult
    private func makeLegacy(in context: ModelContext) -> StudyModule {
        let module = StudyModule(name: "Biology (Sample)", details: "An example module. Delete it whenever you like.", colorName: "green")
        context.insert(module)
        let entries = [
            ("Cell Structure", "cell-structure.md", SourceKind.markdown, MarkdownParser.parse(SampleData.cellStructureMarkdown).cards),
            ("Key Vocabulary", "vocabulary.csv", SourceKind.csv, CSVParser.parse(SampleData.vocabularyCSV).cards),
        ]
        for (index, entry) in entries.enumerated() {
            let chapter = Chapter(name: entry.0, sortIndex: index)
            context.insert(chapter)
            chapter.module = module
            module.chapters = module.chapterList.filter { $0 !== chapter } + [chapter]
            CardStore.addCards(entry.3, to: chapter, fileName: entry.1, kind: entry.2, in: context)
        }
        return module
    }
}
