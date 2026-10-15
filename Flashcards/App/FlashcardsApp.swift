import SwiftData
import SwiftUI

@main
struct FlashcardsApp: App {
    @State private var container: ModelContainer?
    @State private var loadingError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    AppRootView()
                        .modelContainer(container)
                } else if let loadingError {
                    ContentUnavailableView {
                        Label("Unable to Open Library", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Your saved library has not been deleted. \(loadingError)")
                    } actions: {
                        Button("Try Again", action: openLibrary)
                    }
                } else {
                    ProgressView("Opening Flashies…")
                }
            }
            .task { if container == nil { openLibrary() } }
        }
    }

    private func openLibrary() {
        do {
            container = try AppPersistence.makeContainer()
            loadingError = nil
        } catch {
            loadingError = error.localizedDescription
        }
    }
}
