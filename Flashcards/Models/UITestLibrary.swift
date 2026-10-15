#if DEBUG
import Foundation
import SwiftData

/// Deterministic, in-memory content used only by UI tests and screenshot capture.
@MainActor
enum UITestLibrary {
    static func seed(into context: ModelContext) throws {
        SampleData.insertSampleModule(into: context)
        let module = try context.fetch(FetchDescriptor<StudyModule>())[0]
        module.name = "Biology"
        module.details = "Cells, organelles and the language of life."
        for (index, card) in module.allCards.enumerated() {
            card.isFavorite = index % 3 == 0
            card.tagText = index % 2 == 0 ? "exam, cells" : "vocabulary"
            if index < 5 {
                for day in 1...3 {
                    let reviewDate = Calendar.current.date(byAdding: .day, value: -day, to: .now)!
                    let review = ReviewRecord(reviewedAt: reviewDate, wasCorrect: index % 2 == 0)
                    context.insert(review)
                    review.card = card
                }
                card.recordReview(correct: index % 2 == 0, at: .now.addingTimeInterval(-172_800))
            }
        }
        let languages = StudyModule(name: "Spanish", details: "Everyday words, one card at a time.", colorName: "orange")
        let chapter = Chapter(name: "Everyday Words", sortIndex: 0)
        context.insert(languages)
        context.insert(chapter)
        chapter.module = languages
        CardStore.addCards([
            ParsedCard(front: "hola", back: "hello"),
            ParsedCard(front: "gracias", back: "thank you"),
            ParsedCard(front: "hasta mañana", back: "see you tomorrow"),
        ], to: chapter, fileName: "spanish.csv", kind: .csv, in: context)
        try context.save()
    }
}
#endif
