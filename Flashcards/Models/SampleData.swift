import Foundation
import SwiftData

/// The IN3017 sample, with one chapter for each of the five supplied teaching weeks.
enum SampleData {
    struct Content: Decodable {
        let name: String
        let details: String
        let weeks: [Week]
    }

    struct Week: Decodable {
        struct Card: Decodable {
            let front: String
            let back: String
        }
        let name: String
        let sources: [String]
        let cards: [Card]

        var parsedCards: [ParsedCard] { cards.map { ParsedCard(front: $0.front, back: $0.back) } }
    }

    static func load() throws -> Content {
        guard let url = Bundle.main.url(forResource: "theory-of-computation", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Content.self, from: Data(contentsOf: url))
    }

    // Original sample text retained only for recognising legacy samples and isolated test fixtures.
    static let cellStructureMarkdown = """
    # Cell Structure

    ## What is a cell?
    The smallest **structural and functional unit** of a living organism.

    ## Mitochondria
    - Produce energy (ATP) through cellular respiration
    - Have their own DNA

    ## Key Terms
    - **Nucleus**: Holds the cell's genetic material (DNA).
    - **Ribosome**: Builds proteins from amino acids.
    - **Cell membrane**: Controls what enters and leaves the cell.

    Q: Which organelle carries out photosynthesis?
    A: The *chloroplast*, found in plant cells.
    """

    static let vocabularyCSV = """
    term,definition
    Osmosis,"Movement of water across a semi-permeable membrane, from low to high solute concentration"
    Diffusion,Movement of particles from an area of high concentration to an area of low concentration
    Enzyme,A protein that speeds up a chemical reaction without being used up
    Homeostasis,Keeping a stable internal environment
    """

    @MainActor
    @discardableResult
    static func insertSampleModule(into context: ModelContext) throws -> StudyModule {
        let content = try load()
        let modules = try context.fetch(FetchDescriptor<StudyModule>())
        if let existing = modules.first(where: { matchesSample($0, content: content) }) {
            return existing
        }
        try context.save()
        let names = Set(modules.map { $0.name.lowercased() })
        var name = content.name
        var suffix = 1
        while names.contains(name.lowercased()) {
            name = "\(content.name) (Sample\(suffix == 1 ? "" : " \(suffix)"))"
            suffix += 1
        }
        let module = insert(content, named: name, into: context)
        do {
            try context.save()
            return module
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    private static func insert(_ content: Content, named name: String, into context: ModelContext) -> StudyModule {
        let module = StudyModule(
            name: name,
            details: content.details,
            colorName: ModuleColor.indigo.rawValue
        )
        context.insert(module)
        for (index, entry) in content.weeks.enumerated() {
            let chapter = Chapter(name: entry.name, sortIndex: index)
            context.insert(chapter)
            chapter.module = module
            module.chapters = module.chapterList.filter { $0 !== chapter } + [chapter]
            CardStore.addCards(entry.parsedCards, to: chapter, fileName: "IN3017-week-\(index + 1).csv", kind: .csv, in: context)
            for card in chapter.cardList {
                card.tagText = "in3017, week \(index + 1)"
            }
        }
        return module
    }

    /// Updates only the exact original sample. Renamed or edited content is never removed.
    @MainActor
    static func replaceLegacySampleIfNeeded(in context: ModelContext) throws {
        let modules = try context.fetch(FetchDescriptor<StudyModule>())
        let legacy = modules.filter(isUneditedLegacySample)
        guard !legacy.isEmpty else { return }
        let content = try load()
        // Avoid colliding with a user-authored Theory of Computation module.
        guard !modules.contains(where: { $0.name == content.name && !matchesSample($0, content: content) }) else { return }
        try context.save()
        if !modules.contains(where: { matchesSample($0, content: content) }) {
            _ = insert(content, named: content.name, into: context)
        }
        legacy.forEach { context.delete($0) }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func matchesSample(_ module: StudyModule, content: Content) -> Bool {
        guard module.details == content.details,
              module.chapterList.count == content.weeks.count else { return false }
        return zip(module.sortedChapters, content.weeks).allSatisfy { chapter, week in
            chapter.name == week.name && chapter.sortedCards.map { ParsedCard(front: $0.front, back: $0.back) } == week.parsedCards
        }
    }

    private static func isUneditedLegacySample(_ module: StudyModule) -> Bool {
        guard module.name == "Biology (Sample)",
              module.details == "An example module. Delete it whenever you like.",
              module.colorName == "green", module.chapterList.count == 2 else { return false }
        let expected = [
            ("Cell Structure", "cell-structure.md", MarkdownParser.parse(cellStructureMarkdown).cards),
            ("Key Vocabulary", "vocabulary.csv", CSVParser.parse(vocabularyCSV).cards),
        ]
        return zip(module.sortedChapters, expected).allSatisfy { chapter, original in
            chapter.name == original.0
                && chapter.fileList.count == 1 && chapter.fileList.first?.fileName == original.1
                && chapter.sortedCards.map { ParsedCard(front: $0.front, back: $0.back) } == original.2
                && chapter.cardList.allSatisfy { !$0.isFavorite && $0.tags.isEmpty }
        }
    }
}
