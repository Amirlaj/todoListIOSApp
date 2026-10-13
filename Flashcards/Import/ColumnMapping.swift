import Foundation

/// Describes which columns of a CSV file or Markdown table hold the front and back of a card.
struct ColumnMapping: Equatable {
    struct ExtraColumn: Equatable {
        var index: Int
        var label: String
    }

    var front: Int
    var back: Int
    /// Additional labelled columns that are appended to the back of the card.
    var extras: [ExtraColumn] = []

    static let positional = ColumnMapping(front: 0, back: 1)

    static let frontNames: Set<String> = [
        "front", "front side", "side 1", "side a", "question", "questions", "q",
        "term", "terms", "word", "words", "prompt", "concept", "keyword", "vocab", "vocabulary",
    ]

    static let backNames: Set<String> = [
        "back", "back side", "side 2", "side b", "answer", "answers", "a",
        "definition", "definitions", "meaning", "meanings", "response", "explanation",
        "description", "translation", "solution",
    ]

    /// Returns a mapping if `cells` looks like a header row, i.e. it names a front or back column.
    static func fromHeader(_ cells: [String]) -> ColumnMapping? {
        guard cells.count >= 2 else { return nil }
        let names = cells.map(normalizedName)
        let frontIndex = names.firstIndex(where: frontNames.contains)
        let backIndex = names.firstIndex(where: backNames.contains)
        switch (frontIndex, backIndex) {
        case (nil, nil):
            return nil
        case let (index?, nil), let (nil, index?):
            // A lone "q" or "a" is more likely data than a header.
            guard names[index].count > 1 else { return nil }
        default:
            break
        }

        let front: Int
        let back: Int
        switch (frontIndex, backIndex) {
        case let (f?, b?) where f != b:
            front = f
            back = b
        case let (f?, _):
            front = f
            back = f == 0 ? 1 : 0
        case let (nil, b?):
            back = b
            front = b == 0 ? 1 : 0
        case (nil, nil):
            return nil
        }
        return ColumnMapping(front: front, back: back, extras: extraColumns(in: cells, excluding: [front, back]))
    }

    /// Uses the first two columns, labelling any further columns with the given header cells.
    static func positional(labels: [String]) -> ColumnMapping {
        ColumnMapping(front: 0, back: 1, extras: extraColumns(in: labels, excluding: [0, 1]))
    }

    /// Builds a card from a row, or returns nil if the front or back is empty.
    func card(from cells: [String]) -> ParsedCard? {
        func cell(_ index: Int) -> String {
            cells.indices.contains(index) ? cells[index].convertingHTMLLineBreaks.trimmed : ""
        }
        let frontText = cell(front)
        var backText = cell(back)
        guard !frontText.isEmpty, !backText.isEmpty else { return nil }

        let extraLines = extras.compactMap { extra -> String? in
            let value = cell(extra.index)
            return value.isEmpty ? nil : "**\(extra.label.prefix(1).uppercased() + extra.label.dropFirst()):** \(value)"
        }
        if !extraLines.isEmpty {
            backText += "\n\n" + extraLines.joined(separator: "\n")
        }
        return ParsedCard(front: frontText, back: backText)
    }

    private static func extraColumns(in cells: [String], excluding used: Set<Int>) -> [ExtraColumn] {
        cells.enumerated().compactMap { index, label in
            let label = label.trimmed
            guard !used.contains(index), !label.isEmpty else { return nil }
            return ExtraColumn(index: index, label: label)
        }
    }

    private static func normalizedName(_ cell: String) -> String {
        var name = cell.trimmed.lowercased()
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "*_`:"))
        return name.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
