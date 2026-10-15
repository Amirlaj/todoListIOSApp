import SwiftData
import SwiftUI

/// Adds a card to a chapter by hand, or edits an existing card.
struct CardEditorView: View {
    let chapter: Chapter
    let card: Flashcard?
    /// Called when the user deletes the card. The presenter deletes it once the sheet is dismissed.
    var onDelete: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var front: String
    @State private var back: String
    @State private var isFavorite: Bool
    @State private var tagText: String
    @State private var isConfirmingDelete = false

    private let details: Details?

    private struct Details {
        let status: CardStatus
        let timesCorrect: Int
        let timesIncorrect: Int
        let sourceFileName: String?
    }

    init(chapter: Chapter, card: Flashcard?, onDelete: (() -> Void)? = nil) {
        self.chapter = chapter
        self.card = card
        self.onDelete = onDelete
        _front = State(initialValue: card?.front ?? "")
        _back = State(initialValue: card?.back ?? "")
        _isFavorite = State(initialValue: card?.isFavorite ?? false)
        _tagText = State(initialValue: card?.tagText ?? "")
        details = card.map {
            Details(
                status: $0.status,
                timesCorrect: $0.timesCorrect,
                timesIncorrect: $0.timesIncorrect,
                sourceFileName: $0.sourceFile?.fileName
            )
        }
    }

    private var trimmedFront: String { front.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedBack: String { back.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Front") {
                    TextField("Question or term", text: $front, axis: .vertical)
                        .lineLimit(2...8)
                        .accessibilityIdentifier("card-front-input")
                }

                Section {
                    TextField("Answer or definition", text: $back, axis: .vertical)
                        .lineLimit(3...14)
                        .accessibilityIdentifier("card-back-input")
                } header: {
                    Text("Back")
                } footer: {
                    Text("Markdown is supported: **bold**, *italic*, `code`, - lists and ``` code blocks.")
                }

                if !trimmedFront.isEmpty || !trimmedBack.isEmpty {
                    Section("Preview") {
                        VStack(alignment: .leading, spacing: 10) {
                            MarkdownText(front)
                                .font(.headline)
                            Divider()
                            MarkdownText(back)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Toggle("Favourite", isOn: $isFavorite)
                    TextField("Tags, separated by commas", text: $tagText)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Organise")
                } footer: {
                    Text("Use tags such as exam, vocabulary or difficult to filter cards in Review.")
                }

                if let details {
                    Section("Progress") {
                        LabeledContent("Status") {
                            CardStatusBadge(status: details.status)
                        }
                        LabeledContent("Times known", value: details.timesCorrect, format: .number)
                        LabeledContent("Times missed", value: details.timesIncorrect, format: .number)
                        if let fileName = details.sourceFileName {
                            LabeledContent("Imported from", value: fileName)
                        }
                    }

                    Section {
                        Button("Delete Card", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(card == nil ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedFront.isEmpty || trimmedBack.isEmpty)
                }
            }
            .confirmationDialog("Delete this card?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete Card", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let savedCard: Flashcard
        if let card {
            card.front = trimmedFront
            card.back = trimmedBack
            savedCard = card
        } else {
            let existingCards = chapter.cardList
            savedCard = Flashcard(front: trimmedFront, back: trimmedBack, sortIndex: chapter.nextCardIndex)
            modelContext.insert(savedCard)
            savedCard.chapter = chapter
            chapter.cards = existingCards + [savedCard]
        }
        savedCard.isFavorite = isFavorite
        savedCard.tagText = CardTags.parse(tagText).joined(separator: ", ")
        CardStore.save(modelContext)
        dismiss()
    }
}

#if DEBUG
#Preview("New Card") {
    let data = PreviewData()
    return CardEditorView(chapter: data.chapter, card: nil)
        .modelContainer(data.container)
}

#Preview("Edit Card") {
    let data = PreviewData()
    return CardEditorView(chapter: data.chapter, card: data.chapter.sortedCards.first)
        .modelContainer(data.container)
}
#endif
