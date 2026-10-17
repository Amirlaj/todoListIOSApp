import Foundation
import SwiftData

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        StudyModule.self, Chapter.self, Flashcard.self, SourceFile.self, ReviewRecord.self,
    ]
}

@MainActor
enum AppPersistence {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.models)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            if !ProcessInfo.processInfo.arguments.contains("--ui-empty") {
                try UITestLibrary.seed(into: container.mainContext)
            }
            return container
        }
        #endif
        // Keep SwiftData's default store location so existing local libraries migrate in place.
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        try SampleData.replaceLegacySampleIfNeeded(in: container.mainContext)
        return container
    }
}
