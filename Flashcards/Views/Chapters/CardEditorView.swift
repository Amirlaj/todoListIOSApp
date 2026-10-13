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
                }

                Section {
                    TextField("Answer or definition", text: $back, axis: .vertical)
                        .lineLimit(3...14)
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
        if let card {
            card.front = trimmedFront
            card.back = trimmedBack
        } else {
            CardStore.addCards([ParsedCard(front: trimmedFront, back: trimmedBack)], to: chapter, in: modelContext)
        }
        CardStore.save(modelContext)
        dismiss()
    }
}
