import Foundation

/// A flashcard extracted from an imported file, before it is saved to the database.
struct ParsedCard: Hashable {
    var front: String
    var back: String

    /// Key used to detect duplicate cards, ignoring case and whitespace differences.
    var duplicateKey: String {
        func normalize(_ text: String) -> String {
            text.lowercased()
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
        }
        return normalize(front) + "\u{1F}" + normalize(back)
    }
}

/// The outcome of parsing one file.
struct ParseResult: Equatable {
    var cards: [ParsedCard] = []
    /// Rows or blocks that looked like cards but were missing a front or a back.
    var skipped: Int = 0
}

/// The kind of file a set of cards was imported from.
enum SourceKind: String, CaseIterable, Codable, Sendable {
    case csv
    case markdown

    var displayName: String {
        switch self {
        case .csv: "CSV"
        case .markdown: "Markdown"
        }
    }

    var systemImage: String {
        switch self {
        case .csv: "tablecells"
        case .markdown: "doc.richtext"
        }
    }
}

extension StringProtocol {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension String {
    var strippingByteOrderMark: String {
        hasPrefix("\u{FEFF}") ? String(dropFirst()) : self
    }

    /// Converts HTML line breaks (common in Anki and spreadsheet exports) to newlines.
    var convertingHTMLLineBreaks: String {
        var result = self
        for tag in ["<br />", "<br/>", "<br>", "<BR />", "<BR/>", "<BR>"] {
            result = result.replacingOccurrences(of: tag, with: "\n")
        }
        return result
    }
}
