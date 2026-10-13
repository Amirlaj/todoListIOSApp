import SwiftData
import SwiftUI

/// Creates a new chapter in a module, or renames an existing one.
struct ChapterEditorView: View {
    let module: StudyModule
    let chapter: Chapter?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var isNameFocused: Bool

    init(module: StudyModule, chapter: Chapter?) {
        self.module = module
        self.chapter = chapter
        _name = State(initialValue: chapter?.name ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Chapter name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit { if !trimmedName.isEmpty { save() } }
                } footer: {
                    if chapter == nil {
                        Text("After creating the chapter, import CSV or Markdown files into it to generate flashcards.")
                    }
                }
            }
            .navigationTitle(chapter == nil ? "New Chapter" : "Rename Chapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(chapter == nil ? "Create" : "Save") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear { isNameFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        if let chapter {
            chapter.name = trimmedName
        } else {
            let newChapter = Chapter(name: trimmedName, sortIndex: module.nextChapterIndex)
            modelContext.insert(newChapter)
            newChapter.module = module
        }
        CardStore.save(modelContext)
        dismiss()
    }
}
