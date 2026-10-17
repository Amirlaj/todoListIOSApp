import SwiftUI

/// Explains which CSV and Markdown layouts are turned into flashcards.
struct FormatGuideView: View {
    @Environment(\.dismiss) private var dismiss

    struct Format: Identifiable {
        let id = UUID()
        let title: String
        let explanation: String
        let example: String
    }

    private let csvFormats = [
        Format(
            title: "Two columns",
            explanation: "The first column is the front, the second is the back. Commas, semicolons, tabs and Excel sep= headers are detected automatically. Export Excel or Numbers workbooks as CSV before importing. UTF-8 and UTF-16 exports are supported.",
            example: """
            Mitochondria,Powerhouse of the cell
            Nucleus,Holds the cell's DNA
            """
        ),
        Format(
            title: "Header row (optional)",
            explanation: "Name your columns front/back, question/answer or term/definition to choose them in any order. Other named columns are added to the back of the card.",
            example: """
            term,definition,example
            Osmosis,Movement of water across a membrane,Raisins swelling in water
            """
        ),
        Format(
            title: "Quotes",
            explanation: "Wrap text in double quotes when it contains commas or line breaks. Write \"\" for a quote character.",
            example: """
            "Phases of mitosis","Prophase, metaphase, anaphase, telophase"
            """
        ),
    ]

    private let markdownFormats = [
        Format(
            title: "Headings",
            explanation: "Each heading becomes the front and the text below it becomes the back. A single # title at the top is ignored.",
            example: """
            # Biology Notes

            ## What is a cell?
            The basic unit of life.

            ## Mitochondria
            - Produces ATP
            - Has its own DNA
            """
        ),
        Format(
            title: "Q&A",
            explanation: "Q:/A:, Question:/Answer: or Front:/Back: lines. The answer continues until the next question, heading or --- line.",
            example: """
            Q: What is 2 + 2?
            A: 4

            **Q:** Name the noble gases.
            **A:** He, Ne, Ar, Kr, Xe, Rn
            """
        ),
        Format(
            title: "Inline cards",
            explanation: "Put the front and back on one line separated by ::.",
            example: """
            perro :: dog
            gato :: cat
            """
        ),
        Format(
            title: "Glossary lists",
            explanation: "A bold term followed by a colon or dash.",
            example: """
            - **Cell**: The basic unit of life.
            - **Tissue** – A group of similar cells.
            """
        ),
        Format(
            title: "Tables",
            explanation: "Every row becomes a card. The first column is the front and the second the back, unless the header names them.",
            example: """
            | Term | Definition |
            |------|------------|
            | DNA  | Deoxyribonucleic acid |
            """
        ),
        Format(
            title: "Multi-line cards",
            explanation: "Question lines, a line with only ?, then the answer. A blank line ends the card.",
            example: """
            What are the three
            domains of life?
            ?
            Bacteria, Archaea, Eukarya
            """
        ),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("After picking files you can review the extracted cards and choose which ones to add. Card text can use Markdown such as **bold**, *italic* and `code`.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("CSV files (.csv, .tsv, .txt)") {
                    ForEach(csvFormats) { FormatRow(format: $0) }
                }
                Section("Markdown files (.md, .markdown, .txt)") {
                    ForEach(markdownFormats) { FormatRow(format: $0) }
                }
            }
            .navigationTitle("Supported Formats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    struct FormatRow: View {
        let format: Format

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(format.title)
                    .font(.headline)
                Text(format.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(format.example)
                    .font(.caption.monospaced())
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)
        }
    }
}

#if DEBUG
#Preview("Supported Formats") {
    FormatGuideView()
}
#endif
