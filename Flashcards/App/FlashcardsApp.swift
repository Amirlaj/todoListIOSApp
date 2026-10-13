import SwiftData
import SwiftUI

@main
struct FlashcardsApp: App {
    var body: some Scene {
        WindowGroup {
            ModuleListView()
        }
        .modelContainer(for: [StudyModule.self, Chapter.self, Flashcard.self, SourceFile.self])
    }
}
