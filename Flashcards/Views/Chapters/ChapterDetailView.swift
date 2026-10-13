import SwiftData
import SwiftUI

/// A chapter's flashcards and imported files. Files are imported from the toolbar's + menu.
struct ChapterDetailView: View {
    let chapter: Chapter

    @Environment(\.modelContext) private var modelContext

    @State private var isImporting = false
    @State private var importBatch: ImportBatch?
    @State private var importError: String?
    @State private var isAddingCard = false
    @State private var editingCard: Flashcard?
    @State private var cardPendingDeletion: Flashcard?
    @State private var isShowingFormats = false
    @State private var studySession: StudySession?
    @State private var fileToDelete: SourceFile?
    @State private var isConfirmingReset = false
    @State private var searchText = ""

    var body: some View {
        Group {
            if chapter.cards.isEmpty && chapter.sourceFiles.isEmpty {
                emptyState
            } else {
                chapterContent
            }
        }
        .navigationTitle(chapter.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addMenu
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: FlashcardImporter.allowedContentTypes,
            allowsMultipleSelection: true,
            onCompletion: handlePickedFiles
        )
        .sheet(item: $importBatch) { batch in
            ImportPreviewView(chapter: chapter, batch: batch)
        }
        .sheet(isPresented: $isAddingCard) {
            CardEditorView(chapter: chapter, card: nil)
        }
        .sheet(item: $editingCard, onDismiss: deletePendingCard) { card in
            CardEditorView(chapter: chapter, card: card) {
                cardPendingDeletion = card
            }
        }
        .sheet(isPresented: $isShowingFormats) {
            FormatGuideView()
        }
        .fullScreenCover(item: $studySession) { session in
            StudyView(session: session)
        }
        .confirmationDialog(
            "Delete this file?",
            isPresented: .isPresent($fileToDelete),
            titleVisibility: .visible,
            presenting: fileToDelete
        ) { file in
            Button("Delete File and \(file.cards.count) Card(s)", role: .destructive) {
                modelContext.delete(file)
                CardStore.save(modelContext)
            }
        } message: { file in
            Text("All flashcards imported from “\(file.fileName)” will be removed from this chapter.")
        }
        .confirmationDialog("Reset study progress?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Reset Progress", role: .destructive) {
                chapter.cards.forEach { $0.resetProgress() }
                CardStore.save(modelContext)
            }
        } message: {
            Text("Every card in this chapter will be marked as new again.")
        }
        .alert("Import Failed", isPresented: .isPresent($importError)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: - Content

    private var chapterContent: some View {
        List {
            Section {
                studyHeader
            }

            if !chapter.sourceFiles.isEmpty {
                Section("Imported Files") {
                    ForEach(chapter.sortedSourceFiles) { file in
                        SourceFileRow(file: file)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    fileToDelete = file
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                }
            }

            Section {
                let cards = filteredCards
                if cards.isEmpty {
                    Text(searchText.isEmpty ? "No flashcards yet." : "No flashcards match “\(searchText)”.")
                        .foregroundStyle(.secondary)
                }
                ForEach(cards) { card in
                    Button {
                        editingCard = card
                    } label: {
                        CardRow(card: card)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(card)
                            CardStore.save(modelContext)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Flashcards (\(chapter.cards.count))")
            }
        }
        .searchable(text: $searchText, prompt: "Search flashcards")
    }

    private var studyHeader: some View {
        let unmastered = chapter.cards.count - chapter.masteredCount

        return VStack(spacing: 14) {
            HStack {
                StatView(value: chapter.cards.count, label: "Cards")
                StatView(value: chapter.newCount, label: "New", tint: .blue)
                StatView(value: chapter.learningCount, label: "Learning", tint: .orange)
                StatView(value: chapter.masteredCount, label: "Mastered", tint: .green)
            }

            ProgressView(value: chapter.progress)
                .tint(.green)

            Button {
                studySession = StudySession(title: chapter.name, cards: chapter.sortedCards)
            } label: {
                Label("Study All", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(chapter.cards.isEmpty)

            Button {
                studySession = StudySession(
                    title: chapter.name,
                    cards: chapter.sortedCards.filter { !$0.isMastered }
                )
            } label: {
                Label("Study Unmastered (\(unmastered))", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(unmastered == 0)
        }
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Flashcards Yet", systemImage: "rectangle.on.rectangle.angled")
        } description: {
            Text("Import a CSV or Markdown file and its contents will be turned into flashcards for this chapter.")
        } actions: {
            Button {
                isImporting = true
            } label: {
                Label("Import CSV or Markdown", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)

            Button("Add a Card Manually") {
                isAddingCard = true
            }

            Button("Supported Formats") {
                isShowingFormats = true
            }
            .font(.footnote)
        }
    }

    private var addMenu: some View {
        Menu {
            Button {
                isImporting = true
            } label: {
                Label("Import CSV or Markdown", systemImage: "square.and.arrow.down")
            }
            Button {
                isAddingCard = true
            } label: {
                Label("Add Card Manually", systemImage: "square.and.pencil")
            }
            Divider()
            Button {
                isShowingFormats = true
            } label: {
                Label("Supported Formats", systemImage: "questionmark.circle")
            }
            if !chapter.cards.isEmpty {
                Button(role: .destructive) {
                    isConfirmingReset = true
                } label: {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
    }

    private var filteredCards: [Flashcard] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cards = chapter.sortedCards
        guard !query.isEmpty else { return cards }
        return cards.filter {
            $0.front.localizedCaseInsensitiveContains(query) || $0.back.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Actions

    private func handlePickedFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let parsedFiles = urls.map { url -> ParsedFile in
                FlashcardImporter.parsePickedFile(at: url)
            }
            guard !parsedFiles.isEmpty else { return }
            let batch = ImportBatch(parsedFiles: parsedFiles, existingKeys: chapter.duplicateKeys)
            // Give the document picker time to finish dismissing before presenting the preview.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                importBatch = batch
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func deletePendingCard() {
        guard let card = cardPendingDeletion else { return }
        cardPendingDeletion = nil
        modelContext.delete(card)
        CardStore.save(modelContext)
    }
}

// MARK: - Rows

private struct SourceFileRow: View {
    let file: SourceFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.kind.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(file.kind.displayName) · \(file.cards.count) card(s) · \(file.importedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Swipe left to delete the file and its cards")
    }
}

private struct CardRow: View {
    let card: Flashcard

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                MarkdownText(card.front)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                MarkdownText(card.back)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            CardStatusBadge(status: card.status)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
