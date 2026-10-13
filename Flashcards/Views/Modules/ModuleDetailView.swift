import SwiftData
import SwiftUI

/// A module's chapters, with a shortcut to study every card in the module.
struct ModuleDetailView: View {
    let module: StudyModule

    @Environment(\.modelContext) private var modelContext
    @State private var isAddingChapter = false
    @State private var renamingChapter: Chapter?
    @State private var chapterToDelete: Chapter?
    @State private var isEditingModule = false
    @State private var studySession: StudySession?
    @State private var editMode = EditMode.inactive

    var body: some View {
        let chapters = module.sortedChapters

        List {
            Section {
                summary
            }

            Section {
                if chapters.isEmpty {
                    Button {
                        isAddingChapter = true
                    } label: {
                        Label("Add your first chapter", systemImage: "plus.circle")
                    }
                }
                ForEach(chapters) { chapter in
                    NavigationLink(value: chapter) {
                        ChapterRow(chapter: chapter, tint: module.color)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            chapterToDelete = chapter
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)

                        Button {
                            renamingChapter = chapter
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button {
                            renamingChapter = chapter
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            chapterToDelete = chapter
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: moveChapters)
            } header: {
                Text("Chapters")
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(module.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if editMode.isEditing {
                    Button("Done") {
                        withAnimation { editMode = .inactive }
                    }
                    .bold()
                } else {
                    Menu {
                        Button {
                            isEditingModule = true
                        } label: {
                            Label("Edit Module", systemImage: "pencil")
                        }
                        Button {
                            withAnimation { editMode = .active }
                        } label: {
                            Label("Reorder Chapters", systemImage: "arrow.up.arrow.down")
                        }
                        .disabled(chapters.count < 2)
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }

                    Button {
                        isAddingChapter = true
                    } label: {
                        Label("New Chapter", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingChapter) {
            ChapterEditorView(module: module, chapter: nil)
        }
        .sheet(item: $renamingChapter) { chapter in
            ChapterEditorView(module: module, chapter: chapter)
        }
        .sheet(isPresented: $isEditingModule) {
            ModuleEditorView(module: module)
        }
        .fullScreenCover(item: $studySession) { session in
            StudyView(session: session)
        }
        .confirmationDialog(
            "Delete this chapter?",
            isPresented: .isPresent($chapterToDelete),
            titleVisibility: .visible,
            presenting: chapterToDelete
        ) { chapter in
            Button("Delete “\(chapter.name)”", role: .destructive) {
                modelContext.delete(chapter)
                CardStore.save(modelContext)
            }
        } message: { chapter in
            Text("Its \(chapter.cards.count) flashcard(s) and imported files will be deleted.")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !module.details.isEmpty {
                Text(module.details)
                    .foregroundStyle(.secondary)
            }

            HStack {
                StatView(value: module.chapters.count, label: "Chapters")
                StatView(value: module.cardCount, label: "Cards")
                StatView(value: module.masteredCount, label: "Mastered", tint: .green)
            }

            ProgressView(value: module.progress)
                .tint(module.color)

            Button {
                studySession = StudySession(title: module.name, cards: module.allCards)
            } label: {
                Label("Study All Chapters", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(module.color)
            .controlSize(.large)
            .disabled(module.cardCount == 0)
        }
        .padding(.vertical, 6)
    }

    private func moveChapters(from source: IndexSet, to destination: Int) {
        var chapters = module.sortedChapters
        chapters.move(fromOffsets: source, toOffset: destination)
        for (index, chapter) in chapters.enumerated() {
            chapter.sortIndex = index
        }
        CardStore.save(modelContext)
    }
}

private struct ChapterRow: View {
    let chapter: Chapter
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(chapter.name)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if !chapter.cards.isEmpty {
                ProgressRing(progress: chapter.progress, tint: tint)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let cards = chapter.cards.count
        let files = chapter.sourceFiles.count
        var parts = ["\(cards) card\(cards == 1 ? "" : "s")"]
        if files > 0 {
            parts.append("\(files) file\(files == 1 ? "" : "s")")
        }
        if cards > 0 {
            parts.append("\(chapter.masteredCount) mastered")
        }
        return parts.joined(separator: " · ")
    }
}
