#if DEBUG
import SwiftData

/// Each preview gets its own disposable store, including working model relationships.
@MainActor
final class PreviewData {
    let container: ModelContainer
    let module: StudyModule
    let chapter: Chapter

    init(includeCards: Bool = true) {
        do {
            let schema = Schema(AppSchema.models)
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            container = try ModelContainer(for: schema, configurations: [configuration])
            module = StudyModule(
                name: "Biology",
                details: "Explore cells and the building blocks of life.",
                colorName: "green"
            )
            chapter = Chapter(name: "Cell Structure", sortIndex: 0)

            let context = container.mainContext
            context.insert(module)
            context.insert(chapter)
            chapter.module = module

            if includeCards {
                CardStore.addCards(
                    MarkdownParser.parse(SampleData.cellStructureMarkdown).cards,
                    to: chapter,
                    fileName: "cell-structure.md",
                    kind: .markdown,
                    in: context
                )
                for (index, card) in chapter.sortedCards.enumerated() {
                    switch index % 3 {
                    case 0:
                        for _ in 0..<Flashcard.masteredBox {
                            card.recordReview(correct: true)
                        }
                    case 1:
                        card.recordReview(correct: false)
                    default:
                        break
                    }
                }
            }
            try context.save()
        } catch {
            fatalError("Could not create preview data: \(error)")
        }
    }
}
#endif
