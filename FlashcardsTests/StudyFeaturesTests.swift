import Foundation
import SwiftData
import Testing
@testable import Flashcards

@MainActor
struct StudyFeaturesTests {
    @Test func reviewIntervalsExpandAndMissesResetTheSchedule() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let card = Flashcard(front: "Front", back: "Back", sortIndex: 0)
        #expect(card.isDue(at: now))
        for (index, days) in [1, 3, 7, 14, 30, 30].enumerated() {
            card.recordReview(correct: true, at: now)
            #expect(card.box == min(index + 1, 5))
            #expect(card.dueAt == now.addingTimeInterval(Double(days) * 86_400))
            #expect(!card.isDue(at: now))
            #expect(card.isDue(at: card.dueAt!))
        }
        card.recordReview(correct: false, at: now)
        #expect(card.box == 0)
        #expect(card.dueAt == now.addingTimeInterval(600))
        card.resetProgress()
        #expect(card.dueAt == nil)
        #expect(card.isDue(at: now))
    }

    @Test func reviewIsPersistedAlongsideTheCard() throws {
        let data = PreviewData()
        let card = try #require(data.chapter.sortedCards.first)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try StudyStore.review(card, correct: true, at: now, in: data.container.mainContext)
        let context = ModelContext(data.container)
        let records = try context.fetch(FetchDescriptor<ReviewRecord>())
        #expect(records.count == 1)
        #expect(records.first?.wasCorrect == true)
        #expect(records.first?.reviewedAt == now)
        #expect(records.first?.card?.front == card.front)
        #expect(records.first?.card?.dueAt == card.dueAt)
    }

    @Test func tagsAreNormalizedWithoutDuplicates() {
        #expect(CardTags.parse(" Exam, biology ,EXAM,, Difficult ") == ["exam", "biology", "difficult"])
        #expect(CardTags.parse(" , ").isEmpty)
    }

    @Test func statisticsCountReviewsAndCalendarDayStreaks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 12))!
        let records = [0, 0, -1, -2, -4].enumerated().map { index, day in
            ReviewRecord(reviewedAt: calendar.date(byAdding: .day, value: day, to: now)!, wasCorrect: index < 3)
        }
        let metrics = StudyMetrics(reviews: records)
        #expect(metrics.count(on: now, calendar: calendar) == 2)
        #expect(metrics.accuracy == 0.6)
        #expect(metrics.streak(at: now, calendar: calendar) == 3)
        #expect(metrics.streak(at: now.addingTimeInterval(86_400), calendar: calendar) == 3)
        #expect(metrics.streak(at: now.addingTimeInterval(172_800), calendar: calendar) == 0)
        #expect(StudyMetrics(reviews: []).streak(at: now) == 0)
    }

    @Test func reminderUsesLocalTimeAndBoundsInvalidValues() {
        #expect(ReminderTime(hour: 19, minute: 30).dateComponents == DateComponents(hour: 19, minute: 30))
        #expect(ReminderTime(hour: 29, minute: -1).dateComponents == DateComponents(hour: 23, minute: 0))
    }

    @Test func moduleBackupRoundTripsMetadataAndReviewHistory() throws {
        let data = PreviewData()
        let card = try #require(data.chapter.sortedCards.first)
        card.tagText = "exam, cells"
        card.isFavorite = true
        try StudyStore.review(card, correct: true, in: data.container.mainContext)
        let second = Chapter(name: "Empty chapter", sortIndex: 1)
        data.container.mainContext.insert(second)
        second.module = data.module
        try data.container.mainContext.save()

        let archive = try ModuleArchive.decode(ModuleTransfer.archive(data.module).encoded())
        let restored = try ModuleTransfer.restore(archive, named: archive.name, keepingProgress: true, in: data.container.mainContext)
        #expect(restored.name == "Biology (Imported)")
        #expect(restored.details == data.module.details)
        #expect(restored.colorName == data.module.colorName)
        #expect(restored.sortedChapters.map(\.name) == ["Cell Structure", "Empty chapter"])
        let copy = try #require(restored.allCards.first)
        #expect(copy.isFavorite)
        #expect(copy.tags == ["exam", "cells"])
        #expect(copy.dueAt?.timeIntervalSince1970 ?? 0 > 0)
        #expect(copy.reviewList.count == 1)
        #expect(copy.reviewList.first?.wasCorrect == true)
        #expect(copy.reviewList.first?.card === copy)

        let fresh = try ModuleTransfer.restore(archive, named: archive.name, keepingProgress: false, in: data.container.mainContext)
        #expect(fresh.name == "Biology (Imported 2)")
        #expect(fresh.allCards.allSatisfy { $0.dueAt == nil && $0.box == 0 && $0.reviewList.isEmpty })
        #expect(fresh.allCards.first?.isFavorite == true)
    }

    @Test func malformedModuleDoesNotLeaveAPartialRestore() throws {
        let data = PreviewData()
        var archive = ModuleTransfer.archive(data.module)
        archive.chapters.append(archive.chapters[0])
        archive.chapters[1].cards[0].back = ""
        #expect(throws: ChapterArchive.ArchiveError.self) {
            try ModuleTransfer.restore(archive, named: archive.name, keepingProgress: true, in: data.container.mainContext)
        }
        #expect(try data.container.mainContext.fetchCount(FetchDescriptor<StudyModule>()) == 1)
        #expect(try data.container.mainContext.fetchCount(FetchDescriptor<Chapter>()) == 1)
    }

    @Test func originalChapterFilesWithoutNewFieldsStillDecode() throws {
        let data = Data("""
        {"format":"com.amirlaj.Flashcards.chapter","version":1,"name":"Old Chapter","createdAt":1700000000000,"sources":[],"cards":[{"front":"Q","back":"A","createdAt":1700000000000,"box":0,"timesCorrect":0,"timesIncorrect":0}]}
        """.utf8)
        let archive = try ChapterArchive.decode(data)
        #expect(archive.cards.count == 1)
        #expect(archive.cards[0].tags == nil)
        #expect(archive.cards[0].reviews == nil)
    }

    @Test func moduleDocumentAndEmptyModuleRoundTrip() throws {
        let archive = ModuleArchive(name: "Empty", details: "", colorName: "blue", createdAt: .now, chapters: [])
        let document = try ModuleDocument(archive: archive)
        let decoded = try ModuleArchive.decode(document.data)
        #expect(decoded.name == archive.name)
        #expect(decoded.chapters.isEmpty)
        #expect(decoded.cardCount == 0)
    }
}
