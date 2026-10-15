import SwiftData
import SwiftUI

struct ChapterImportView: View {
    let archive: ChapterArchive
    let module: StudyModule

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var keepProgress = true
    @State private var importError: String?

    init(archive: ChapterArchive, module: StudyModule) {
        self.archive = archive
        self.module = module
        _name = State(initialValue: ChapterTransfer.availableName(archive.name, in: module))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Chapter name", text: $name)
                    LabeledContent("Module", value: module.name)
                    LabeledContent("Flashcards", value: archive.cards.count, format: .number)
                } footer: {
                    Text("A new chapter will be added. Existing chapters stay unchanged; matching names get an Imported suffix.")
                }

                Section {
                    Toggle("Keep Study Progress", isOn: $keepProgress)
                } footer: {
                    Text(keepProgress
                         ? "Restore the saved mastery levels and review counts."
                         : "Start with every imported card marked as new.")
                }

                if !archive.cards.isEmpty {
                    Section("Card Preview") {
                        ForEach(Array(archive.cards.prefix(5).enumerated()), id: \.offset) { _, card in
                            VStack(alignment: .leading, spacing: 6) {
                                MarkdownText(card.front).font(.headline)
                                MarkdownText(card.back).foregroundStyle(.secondary)
                            }
                            .lineLimit(4)
                            .padding(.vertical, 4)
                        }
                        if archive.cards.count > 5 {
                            Text("And \(archive.cards.count - 5) more cards")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Import Chapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { importChapter() }
                        .disabled(name.trimmed.isEmpty)
                }
            }
            .alert("Import Failed", isPresented: .isPresent($importError)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func importChapter() {
        do {
            try ChapterTransfer.importChapter(
                archive, named: name, into: module, keepingProgress: keepProgress, in: modelContext
            )
            dismiss()
        } catch {
            importError = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview("Import Chapter") {
    let data = PreviewData()
    return ChapterImportView(archive: ChapterTransfer.archive(data.chapter), module: data.module)
        .modelContainer(data.container)
}
#endif
