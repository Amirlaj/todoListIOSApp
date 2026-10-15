import Foundation
import SwiftData

@MainActor
enum ChapterTransfer {
    static func archive(_ chapter: Chapter) -> ChapterArchive {
        let files = chapter.sortedSourceFiles
        let sourceIDs = Dictionary(uniqueKeysWithValues: files.map { ($0.persistentModelID, UUID()) })
        return ChapterArchive(
            name: chapter.name,
            createdAt: chapter.createdAt,
            sources: files.map {
                ChapterArchive.Source(
                    id: sourceIDs[$0.persistentModelID]!,
                    fileName: $0.fileName,
                    kind: $0.kind,
                    importedAt: $0.importedAt
                )
            },
            cards: chapter.sortedCards.map {
                ChapterArchive.Card(
                    front: $0.front,
                    back: $0.back,
                    createdAt: $0.createdAt,
                    sourceID: $0.sourceFile.flatMap { sourceIDs[$0.persistentModelID] },
                    box: $0.box,
                    timesCorrect: $0.timesCorrect,
                    timesIncorrect: $0.timesIncorrect,
                    lastReviewedAt: $0.lastReviewedAt,
                    dueAt: $0.dueAt,
                    isFavorite: $0.isFavorite,
                    tags: $0.tags,
                    reviews: $0.reviewList.sorted { $0.reviewedAt < $1.reviewedAt }.map {
                        ChapterArchive.Review(reviewedAt: $0.reviewedAt, wasCorrect: $0.wasCorrect)
                    }
                )
            }
        )
    }

    static func availableName(_ name: String, in module: StudyModule) -> String {
        let base = name.trimmed.isEmpty ? "Imported Chapter" : name.trimmed
        let existing = Set(module.chapterList.map { $0.name.trimmed.lowercased() })
        guard existing.contains(base.lowercased()) else { return base }
        var candidate = "\(base) (Imported)"
        var suffix = 2
        while existing.contains(candidate.lowercased()) {
            candidate = "\(base) (Imported \(suffix))"
            suffix += 1
        }
        return candidate
    }

    @discardableResult
    static func importChapter(
        _ archive: ChapterArchive,
        named name: String,
        into module: StudyModule,
        keepingProgress: Bool,
        in context: ModelContext
    ) throws -> Chapter {
        _ = try archive.validated()
        // Preserve earlier edits before establishing the import's rollback boundary.
        try context.save()
        let chapter = insertValidatedChapter(
            archive, named: availableName(name, in: module), into: module,
            keepingProgress: keepingProgress, in: context
        )
        do {
            try context.save()
            return chapter
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Used inside a chapter or module import transaction, after archive validation.
    static func insertValidatedChapter(
        _ archive: ChapterArchive, named name: String, into module: StudyModule,
        keepingProgress: Bool, in context: ModelContext
    ) -> Chapter {
        let existingChapters = module.chapterList
        let chapter = Chapter(name: name, sortIndex: module.nextChapterIndex)
        context.insert(chapter)
        chapter.module = module
        module.chapters = existingChapters + [chapter]
        chapter.createdAt = archive.createdAt

        var sources: [UUID: SourceFile] = [:]
        for entry in archive.sources {
            let source = SourceFile(fileName: entry.fileName, kind: entry.kind)
            context.insert(source)
            source.chapter = chapter
            source.importedAt = entry.importedAt
            sources[entry.id] = source
        }
        for (index, entry) in archive.cards.enumerated() {
            let card = Flashcard(front: entry.front, back: entry.back, sortIndex: index)
            context.insert(card)
            card.chapter = chapter
            card.sourceFile = entry.sourceID.flatMap { sources[$0] }
            card.createdAt = entry.createdAt
            card.isFavorite = entry.isFavorite ?? false
            card.tagText = CardTags.parse((entry.tags ?? []).joined(separator: ",")).joined(separator: ", ")
            if keepingProgress {
                card.box = entry.box
                card.timesCorrect = entry.timesCorrect
                card.timesIncorrect = entry.timesIncorrect
                card.lastReviewedAt = entry.lastReviewedAt
                card.dueAt = entry.dueAt ?? entry.lastReviewedAt.map { ReviewSchedule.nextDate(box: entry.box, after: $0) }
                for review in entry.reviews ?? [] {
                    let record = ReviewRecord(reviewedAt: review.reviewedAt, wasCorrect: review.wasCorrect)
                    context.insert(record)
                    record.card = card
                }
            }
        }
        return chapter
    }
}
