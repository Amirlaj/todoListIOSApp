import Foundation
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import Flashcards

struct ChapterArchiveTests {
    private func sample() -> ChapterArchive {
        ChapterArchive(
            name: "Cells 🧬",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sources: [],
            cards: [ChapterArchive.Card(
                front: "What does \"cell\" mean, exactly?",
                back: "**Life's building block**\n- Plant 🌱\n- Animal",
                createdAt: Date(timeIntervalSince1970: 1_700_000_001),
                sourceID: nil,
                box: 3,
                timesCorrect: 4,
                timesIncorrect: 1,
                lastReviewedAt: Date(timeIntervalSince1970: 1_700_000_002)
            )]
        )
    }

    @Test func archiveRoundTripPreservesContentAndProgress() throws {
        let archive = sample()
        #expect(try ChapterArchive.decode(archive.encoded()) == archive)
    }

    @Test func csvRoundTripHandlesQuotesCommasNewlinesAndUnicode() {
        let archive = sample()
        let result = CSVParser.parse(archive.csv)
        #expect(result.cards == archive.cards.map { ParsedCard(front: $0.front, back: $0.back) })
        #expect(result.skipped == 0)
    }

    @Test func emptyChapterRoundTrips() throws {
        var archive = sample()
        archive.cards = []
        #expect(try ChapterArchive.decode(archive.encoded()) == archive)
        #expect(archive.csv == "front,back\r\n")
    }

    @Test func malformedAndUnrelatedFilesAreRejected() {
        for content in ["not JSON", "{}", "{\"format\":\"another-app\",\"version\":1}"] {
            #expect(throws: ChapterArchive.ArchiveError.self) {
                try ChapterArchive.decode(Data(content.utf8))
            }
        }
    }

    @Test func futureVersionIsReportedBeforeDecodingItsSchema() {
        let data = Data("{\"format\":\"com.amirlaj.Flashcards.chapter\",\"version\":99}".utf8)
        do {
            _ = try ChapterArchive.decode(data)
            Issue.record("A newer version should be rejected")
        } catch ChapterArchive.ArchiveError.unsupportedVersion(let version) {
            #expect(version == 99)
        } catch {
            Issue.record("Expected the unsupported-version error, got \(error)")
        }
    }

    @Test func invalidCardsAndSourceReferencesAreRejected() {
        var archive = sample()
        archive.cards[0].sourceID = UUID()
        #expect(throws: ChapterArchive.ArchiveError.self) { try archive.validated() }
        archive = sample()
        archive.cards[0].box = 6
        #expect(throws: ChapterArchive.ArchiveError.self) { try archive.validated() }
        archive = sample()
        archive.cards[0].timesCorrect = -1
        #expect(throws: ChapterArchive.ArchiveError.self) { try archive.validated() }
        archive = sample()
        archive.cards[0].back = " \n"
        #expect(throws: ChapterArchive.ArchiveError.self) { try archive.validated() }
        archive = sample()
        archive.name = " "
        #expect(throws: ChapterArchive.ArchiveError.self) { try archive.validated() }
    }

    @Test func duplicateSourceIDsAreRejected() {
        var archive = sample()
        let source = ChapterArchive.Source(id: UUID(), fileName: "cells.md", kind: .markdown, importedAt: .now)
        archive.sources = [source, source]
        #expect(throws: ChapterArchive.ArchiveError.self) { try archive.validated() }
    }

    @Test func exportedDocumentCanBeReadFromDisk() throws {
        let archive = sample()
        let document = try ChapterDocument(archive: archive)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".flashies")
        defer { try? FileManager.default.removeItem(at: url) }
        try document.data.write(to: url)
        #expect(try ChapterDocument.readChapter(at: url) == archive)
        #expect(try ChapterDocument(archive: archive, asCSV: true).data == Data(archive.csv.utf8))
        #expect(UTType.flashiesChapter.preferredFilenameExtension == "flashies")
    }

    @Test func exportFilenamesAreSafe() {
        var archive = sample()
        archive.name = "../Cells/Parts: Quiz\n"
        #expect(archive.suggestedFilename == "-Cells-Parts- Quiz-")
        archive.name = " . "
        #expect(archive.suggestedFilename == "Chapter")
    }
}

@MainActor
struct ChapterTransferTests {
    @Test func importRestoresRelationshipsOrderAndProgress() throws {
        let data = PreviewData()
        let manual = Flashcard(front: "Manual card", back: "No source file", sortIndex: data.chapter.nextCardIndex)
        data.container.mainContext.insert(manual)
        manual.chapter = data.chapter
        try data.container.mainContext.save()
        let archive = try ChapterArchive.decode(ChapterTransfer.archive(data.chapter).encoded())

        let imported = try ChapterTransfer.importChapter(
            archive, named: archive.name, into: data.module, keepingProgress: true, in: data.container.mainContext
        )

        #expect(imported !== data.chapter)
        #expect(imported.name == "Cell Structure (Imported)")
        #expect(data.module.sortedChapters.last === imported)
        #expect(imported.sortedCards.map(\.front) == archive.cards.map(\.front))
        #expect(imported.sortedCards.map(\.back) == archive.cards.map(\.back))
        #expect(imported.sortedCards.map(\.box) == archive.cards.map(\.box))
        #expect(imported.sortedCards.map(\.timesCorrect) == archive.cards.map(\.timesCorrect))
        #expect(imported.sortedCards.map(\.timesIncorrect) == archive.cards.map(\.timesIncorrect))
        #expect(imported.sortedCards.map(\.lastReviewedAt) == archive.cards.map(\.lastReviewedAt))
        #expect(imported.fileList.count == 1)
        let source = try #require(imported.fileList.first)
        #expect(source.fileName == "cell-structure.md")
        #expect(source.kind == .markdown)
        #expect(source.chapter === imported)
        #expect(source.cardList.count == archive.cards.count - 1)
        #expect(imported.sortedCards.first?.sourceFile === source)
        #expect(imported.sortedCards.last?.sourceFile == nil)
        #expect(imported.cardList.allSatisfy { $0.chapter === imported })
        #expect(data.chapter.cardList.count == archive.cards.count)

        // Read through a fresh context to verify the imported graph was persisted.
        let freshContext = ModelContext(data.container)
        let chapters = try freshContext.fetch(FetchDescriptor<Chapter>())
        let saved = try #require(chapters.first { $0.name == imported.name })
        #expect(saved.cardList.count == archive.cards.count)
        #expect(saved.module?.name == data.module.name)
        #expect(saved.fileList.first?.cardList.count == archive.cards.count - 1)
    }

    @Test func importCanStartWithNewProgressAndHandleRepeatedNames() throws {
        let data = PreviewData()
        let archive = ChapterTransfer.archive(data.chapter)
        for suffix in ["Imported", "Imported 2"] {
            let chapter = try ChapterTransfer.importChapter(
                archive, named: "cell structure", into: data.module,
                keepingProgress: false, in: data.container.mainContext
            )
            #expect(chapter.name == "cell structure (\(suffix))")
            #expect(chapter.cardList.allSatisfy {
                $0.box == 0 && $0.timesCorrect == 0 && $0.timesIncorrect == 0 && $0.lastReviewedAt == nil
            })
        }
        #expect(data.module.chapterList.count == 3)
        #expect(data.chapter.masteredCount > 0)
    }

    @Test func emptyChapterCanBeImportedIntoAnotherModule() throws {
        let data = PreviewData(includeCards: false)
        let other = StudyModule(name: "Revision")
        data.container.mainContext.insert(other)
        let archive = ChapterTransfer.archive(data.chapter)
        let chapter = try ChapterTransfer.importChapter(
            archive, named: "My Chapter", into: other, keepingProgress: true, in: data.container.mainContext
        )
        #expect(chapter.name == "My Chapter")
        #expect(chapter.module === other)
        #expect(chapter.cardList.isEmpty)
        #expect(chapter.fileList.isEmpty)
    }

    @Test func invalidImportDoesNotChangeExistingData() {
        let data = PreviewData()
        var archive = ChapterTransfer.archive(data.chapter)
        archive.cards[0].sourceID = UUID()
        let count = data.chapter.cardList.count
        #expect(throws: ChapterArchive.ArchiveError.self) {
            try ChapterTransfer.importChapter(
                archive, named: archive.name, into: data.module, keepingProgress: true, in: data.container.mainContext
            )
        }
        #expect(data.module.chapterList.count == 1)
        #expect(data.chapter.cardList.count == count)
        #expect(!data.container.mainContext.hasChanges)
    }
}
