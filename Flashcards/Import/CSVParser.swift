import Foundation

/// Turns CSV / TSV text into flashcards.
///
/// - The delimiter (comma, semicolon or tab) is detected automatically.
/// - Quoted fields may contain delimiters, newlines and escaped quotes (`""`).
/// - An optional header row such as `front,back`, `question,answer` or `term,definition`
///   picks the columns; without one, the first column is the front and the second the back.
enum CSVParser {
    static func parse(_ text: String, delimiter: Character? = nil) -> ParseResult {
        let text = text.strippingByteOrderMark
        let delimiter = delimiter ?? detectDelimiter(in: text)
        let rows = rows(from: text, delimiter: delimiter).filter { row in
            row.contains { !$0.trimmed.isEmpty }
        }
        guard let firstRow = rows.first else { return ParseResult() }

        var mapping = ColumnMapping.positional
        var dataRows = rows[...]
        if let headerMapping = ColumnMapping.fromHeader(firstRow) {
            mapping = headerMapping
            dataRows = rows.dropFirst()
        }

        var result = ParseResult()
        for row in dataRows {
            if let card = mapping.card(from: row) {
                result.cards.append(card)
            } else {
                result.skipped += 1
            }
        }
        return result
    }

    /// Splits CSV text into rows of fields (RFC 4180 style).
    static func rows(from text: String, delimiter: Character) -> [[String]] {
        let characters = Array(text)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"", field.allSatisfy({ $0 == " " }) {
                field = ""
                inQuotes = true
            } else if character == delimiter {
                row.append(field)
                field = ""
            } else if character.isNewline {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }
            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    /// Picks the delimiter that appears on the most lines (and most consistently) in the first lines of the file.
    static func detectDelimiter(in text: String) -> Character {
        let candidates: [Character] = ["\t", ",", ";"]
        var lineCounts: [[Int]] = []
        var current = [Int](repeating: 0, count: candidates.count)
        var lineHasContent = false
        var inQuotes = false

        for character in text {
            if character == "\"" {
                inQuotes.toggle()
                lineHasContent = true
                continue
            }
            if inQuotes { continue }
            if character.isNewline {
                if lineHasContent { lineCounts.append(current) }
                current = [Int](repeating: 0, count: candidates.count)
                lineHasContent = false
                if lineCounts.count >= 20 { break }
                continue
            }
            if let candidate = candidates.firstIndex(of: character) {
                current[candidate] += 1
            }
            if !character.isWhitespace { lineHasContent = true }
        }
        if lineHasContent { lineCounts.append(current) }

        var best: (index: Int, linesWithDelimiter: Int, consistent: Bool)?
        for index in candidates.indices {
            let counts = lineCounts.map { $0[index] }
            let linesWithDelimiter = counts.filter { $0 > 0 }.count
            guard linesWithDelimiter > 0 else { continue }
            let consistent = Set(counts).count == 1
            if let currentBest = best {
                let isBetter = linesWithDelimiter > currentBest.linesWithDelimiter
                    || (linesWithDelimiter == currentBest.linesWithDelimiter && consistent && !currentBest.consistent)
                if !isBetter { continue }
            }
            best = (index, linesWithDelimiter, consistent)
        }
        return best.map { candidates[$0.index] } ?? ","
    }
}
