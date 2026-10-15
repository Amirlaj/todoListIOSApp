import SwiftData
import SwiftUI

/// Cards extracted from one or more picked files, waiting for the user to review them.
struct ImportBatch: Identifiable {
    struct Candidate: Identifiable {
        let id = UUID()
        let card: ParsedCard
        let isDuplicate: Bool
        var isSelected: Bool
    }

    struct File: Identifiable {
        let id = UUID()
        let fileName: String
        let kind: SourceKind
        let skipped: Int
        let errorMessage: String?
        var candidates: [Candidate]

        var selectedCount: Int { candidates.filter(\.isSelected).count }
        var duplicateCount: Int { candidates.filter(\.isDuplicate).count }
    }

    let id = UUID()
    var files: [File]

    /// Cards that already exist in the chapter (or appear earlier in the batch) start unselected.
    init(parsedFiles: [ParsedFile], existingKeys: Set<String>) {
        var seenKeys = existingKeys
        var files: [File] = []
        for parsed in parsedFiles {
            var candidates: [Candidate] = []
            for card in parsed.cards {
                let isDuplicate = !seenKeys.insert(card.duplicateKey).inserted
                candidates.append(Candidate(card: card, isDuplicate: isDuplicate, isSelected: !isDuplicate))
            }
            files.append(File(
                fileName: parsed.fileName,
                kind: parsed.kind,
                skipped: parsed.skipped,
                errorMessage: parsed.errorMessage,
                candidates: candidates
            ))
        }
        self.files = files
    }
}

/// Lets the user check the extracted cards and choose which ones to add to the chapter.
struct ImportPreviewView: View {
    let chapter: Chapter

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var files: [ImportBatch.File]
    @State private var isShowingFormats = false

    init(chapter: Chapter, batch: ImportBatch) {
        self.chapter = chapter
        _files = State(initialValue: batch.files)
    }

    private var selectedCount: Int {
        files.reduce(0) { $0 + $1.selectedCount }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach($files) { $file in
                    Section {
                        if let message = file.errorMessage {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                            Button("View Supported Formats") {
                                isShowingFormats = true
                            }
                        }
                        ForEach($file.candidates) { $candidate in
                            CandidateRow(candidate: $candidate)
                        }
                    } header: {
                        FileHeader(file: $file)
                    } footer: {
                        if file.errorMessage == nil {
                            Text(footer(for: file))
                        }
                    }
                }
            }
            .navigationTitle("Review Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedCount)") { addSelectedCards() }
                        .disabled(selectedCount == 0)
                }
            }
            .sheet(isPresented: $isShowingFormats) {
                FormatGuideView()
            }
        }
    }

    private func footer(for file: ImportBatch.File) -> String {
        var parts = ["\(file.candidates.count) card(s) found in this \(file.kind.displayName) file"]
        if file.skipped > 0 {
            parts.append("\(file.skipped) incomplete entr\(file.skipped == 1 ? "y" : "ies") skipped")
        }
        if file.duplicateCount > 0 {
            parts.append("\(file.duplicateCount) duplicate(s) left unselected")
        }
        return parts.joined(separator: " · ") + "."
    }

    private func addSelectedCards() {
        for file in files where file.selectedCount > 0 {
            let cards = file.candidates.filter(\.isSelected).map(\.card)
            CardStore.addCards(cards, to: chapter, fileName: file.fileName, kind: file.kind, in: modelContext)
        }
        CardStore.save(modelContext)
        dismiss()
    }
}

private struct FileHeader: View {
    @Binding var file: ImportBatch.File

    private var allSelected: Bool {
        file.candidates.allSatisfy(\.isSelected)
    }

    var body: some View {
        HStack {
            Label(file.fileName, systemImage: file.kind.systemImage)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if !file.candidates.isEmpty {
                Button(allSelected ? "Deselect All" : "Select All") {
                    let select = !allSelected
                    for index in file.candidates.indices {
                        file.candidates[index].isSelected = select
                    }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .textCase(nil)
    }
}

private struct CandidateRow: View {
    @Binding var candidate: ImportBatch.Candidate

    var body: some View {
        Button {
            candidate.isSelected.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(candidate.isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    MarkdownText(candidate.card.front)
                        .font(.body.weight(.semibold))
                        .lineLimit(3)
                    MarkdownText(candidate.card.back)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                    if candidate.isDuplicate {
                        Label("Duplicate card", systemImage: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(candidate.isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview("New and Duplicate Cards") {
    let data = PreviewData()
    let batch = ImportBatch(
        parsedFiles: [
            FlashcardImporter.parse(text: SampleData.cellStructureMarkdown, fileName: "cell-structure.md"),
            FlashcardImporter.parse(text: SampleData.vocabularyCSV, fileName: "vocabulary.csv"),
        ],
        existingKeys: data.chapter.duplicateKeys
    )
    return ImportPreviewView(chapter: data.chapter, batch: batch)
        .modelContainer(data.container)
}

#Preview("Import Error") {
    let data = PreviewData()
    let batch = ImportBatch(
        parsedFiles: [ParsedFile(
            fileName: "empty.csv",
            kind: .csv,
            cards: [],
            errorMessage: FlashcardImporter.noCardsMessage
        )],
        existingKeys: []
    )
    return ImportPreviewView(chapter: data.chapter, batch: batch)
        .modelContainer(data.container)
}
#endif
