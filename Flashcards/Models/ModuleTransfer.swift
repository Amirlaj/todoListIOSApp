import SwiftData

@MainActor
enum ModuleTransfer {
    static func archive(_ module: StudyModule) -> ModuleArchive {
        ModuleArchive(
            name: module.name, details: module.details, colorName: module.colorName,
            createdAt: module.createdAt, chapters: module.sortedChapters.map(ChapterTransfer.archive)
        )
    }

    static func availableName(_ proposed: String, existing: [String]) -> String {
        let name = proposed.trimmed.isEmpty ? "Imported Module" : proposed.trimmed
        let names = Set(existing.map { $0.trimmed.lowercased() })
        guard names.contains(name.lowercased()) else { return name }
        var candidate = "\(name) (Imported)"
        var suffix = 2
        while names.contains(candidate.lowercased()) {
            candidate = "\(name) (Imported \(suffix))"
            suffix += 1
        }
        return candidate
    }

    @discardableResult
    static func restore(_ archive: ModuleArchive, named name: String, keepingProgress: Bool, in context: ModelContext) throws -> StudyModule {
        _ = try archive.validated()
        let names = try context.fetch(FetchDescriptor<StudyModule>()).map(\.name)
        try context.save()
        let module = StudyModule(name: availableName(name, existing: names), details: archive.details, colorName: archive.colorName)
        context.insert(module)
        module.createdAt = archive.createdAt
        for chapter in archive.chapters {
            _ = ChapterTransfer.insertValidatedChapter(
                chapter, named: chapter.name, into: module, keepingProgress: keepingProgress, in: context
            )
        }
        do {
            try context.save()
            return module
        } catch {
            context.rollback()
            throw error
        }
    }
}
