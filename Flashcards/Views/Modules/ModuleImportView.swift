import SwiftData
import SwiftUI

struct ModuleImportView: View {
    let archive: ModuleArchive
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var keepProgress = true
    @State private var importError: String?

    init(archive: ModuleArchive, existingNames: [String]) {
        self.archive = archive
        _name = State(initialValue: ModuleTransfer.availableName(archive.name, existing: existingNames))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Module name", text: $name)
                    LabeledContent("Chapters", value: archive.chapters.count, format: .number)
                    LabeledContent("Cards", value: archive.cardCount, format: .number)
                    Toggle("Keep Study Progress", isOn: $keepProgress)
                } footer: {
                    Text("Restore this backup as a new module. Existing modules stay unchanged. Turn off Keep Study Progress to start fresh; tags and favourites are always kept.")
                }
                Section("Chapters to Import") {
                    ForEach(Array(archive.chapters.enumerated()), id: \.offset) { _, chapter in
                        LabeledContent(chapter.name, value: "\(chapter.cards.count) card(s)")
                    }
                }
            }
            .navigationTitle("Import Module")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        do {
                            try ModuleTransfer.restore(archive, named: name, keepingProgress: keepProgress, in: modelContext)
                            dismiss()
                        } catch {
                            importError = error.localizedDescription
                        }
                    }
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
}

#if DEBUG
#Preview("Restore Module") {
    let data = PreviewData()
    return ModuleImportView(archive: ModuleTransfer.archive(data.module), existingNames: [data.module.name])
        .modelContainer(data.container)
}
#endif
