import SwiftData
import SwiftUI

/// The home screen: every module (subject) the user has created.
struct ModuleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyModule.createdAt) private var modules: [StudyModule]

    @State private var isCreatingModule = false
    @State private var editingModule: StudyModule?
    @State private var moduleToDelete: StudyModule?

    var body: some View {
        NavigationStack {
            Group {
                if modules.isEmpty {
                    emptyState
                } else {
                    moduleList
                }
            }
            .navigationTitle("Modules")
            .navigationDestination(for: StudyModule.self) { module in
                ModuleDetailView(module: module)
            }
            .navigationDestination(for: Chapter.self) { chapter in
                ChapterDetailView(chapter: chapter)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreatingModule = true
                    } label: {
                        Label("New Module", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isCreatingModule) {
                ModuleEditorView(module: nil)
            }
            .sheet(item: $editingModule) { module in
                ModuleEditorView(module: module)
            }
            .confirmationDialog(
                "Delete this module?",
                isPresented: .isPresent($moduleToDelete),
                titleVisibility: .visible,
                presenting: moduleToDelete
            ) { module in
                Button("Delete “\(module.name)”", role: .destructive) {
                    modelContext.delete(module)
                    CardStore.save(modelContext)
                }
            } message: { module in
                Text("Its \(module.chapters.count) chapter(s) and \(module.cardCount) flashcard(s) will be deleted.")
            }
        }
    }

    private var moduleList: some View {
        List {
            ForEach(modules) { module in
                NavigationLink(value: module) {
                    ModuleRow(module: module)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        moduleToDelete = module
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)

                    Button {
                        editingModule = module
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    Button {
                        editingModule = module
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        moduleToDelete = module
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Modules Yet", systemImage: "rectangle.stack")
        } description: {
            Text("Create a module for each subject, add chapters to it, then import CSV or Markdown files to turn them into flashcards.")
        } actions: {
            Button("Create a Module") {
                isCreatingModule = true
            }
            .buttonStyle(.borderedProminent)

            Button("Add a Sample Module") {
                SampleData.insertSampleModule(into: modelContext)
            }
        }
    }
}

private struct ModuleRow: View {
    let module: StudyModule

    var body: some View {
        HStack(spacing: 14) {
            Text(String(module.name.prefix(1)).uppercased())
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(module.color.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(module.name)
                    .font(.headline)
                if !module.details.isEmpty {
                    Text(module.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("\(module.chapters.count) chapter(s) · \(module.cardCount) card(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if module.cardCount > 0 {
                ProgressRing(progress: module.progress, tint: module.color)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.vertical, 4)
    }
}
