import SwiftData
import SwiftUI

struct ReviewLibraryView: View {
    @Query(sort: \Flashcard.createdAt) private var cards: [Flashcard]
    @Environment(\.modelContext) private var modelContext
    @State private var filter = Filter.due
    @State private var search = ""
    @State private var selectedTag = ""
    @State private var session: StudySession?

    enum Filter: String, CaseIterable, Identifiable {
        case due = "Due", favorites = "Favourites", all = "All"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let filtered = filteredCards(at: timeline.date)
                List {
                    Section {
                        Picker("Cards", selection: $filter) {
                            ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        if !allTags.isEmpty {
                            Picker("Tag", selection: $selectedTag) {
                                Text("All tags").tag("")
                                ForEach(allTags, id: \.self) { Text($0).tag($0) }
                            }
                        }
                        Button {
                            session = StudySession(title: filter == .due ? "Due for Review" : filter.rawValue, cards: filtered)
                        } label: {
                            Label("Study \(filtered.count) Card(s)", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(filtered.isEmpty)
                    } footer: {
                        Text("New cards are due now. Known cards return after 1, 3, 7, 14 and 30 days. Missed cards return in 10 minutes.")
                    }

                    if filtered.isEmpty {
                        ContentUnavailableView(
                            filter == .due ? "All Caught Up" : "No Matching Cards",
                            systemImage: filter == .due ? "checkmark.circle" : "magnifyingglass",
                            description: Text(cards.isEmpty ? "Add a module and some cards in Library to begin." : "Try a different filter or come back when more cards are due.")
                        )
                    }
                    ForEach(filtered) { card in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                MarkdownText(card.front).font(.headline).lineLimit(3)
                                Spacer()
                                if card.isFavorite {
                                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                                        .accessibilityLabel("Favourite")
                                }
                            }
                            Text(card.chapter?.name ?? "Flashcard").font(.caption).foregroundStyle(.secondary)
                            if !card.tags.isEmpty {
                                Text(card.tags.map { "#\($0)" }.joined(separator: " "))
                                    .font(.caption).foregroundStyle(.tint)
                            }
                            if let due = card.dueAt, due > timeline.date {
                                Text("Due \(due.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search cards and tags")
            .navigationTitle("Review")
            .fullScreenCover(item: $session) { StudyView(session: $0) }
        }
    }

    private var allTags: [String] { Set(cards.flatMap(\.tags)).sorted() }

    private func filteredCards(at now: Date) -> [Flashcard] {
        let query = search.trimmed
        return cards.filter { card in
            (filter != .due || card.isDue(at: now))
                && (filter != .favorites || card.isFavorite)
                && (selectedTag.isEmpty || card.tags.contains(selectedTag))
                && (query.isEmpty || card.front.localizedCaseInsensitiveContains(query)
                    || card.back.localizedCaseInsensitiveContains(query)
                    || card.tags.contains { $0.localizedCaseInsensitiveContains(query) })
        }.sorted { ($0.dueAt ?? .distantPast) < ($1.dueAt ?? .distantPast) }
    }
}

#if DEBUG
#Preview("Review") {
    let data = PreviewData()
    return ReviewLibraryView().modelContainer(data.container)
}
#endif
