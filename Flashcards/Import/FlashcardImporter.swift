import Foundation

/// The parsed contents of one imported file.
struct ParsedFile: Identifiable {
    let id = UUID()
    var fileName: String
    var kind: SourceKind
    var cards: [ParsedCard]
    var skipped: Int = 0
    var errorMessage: String?
}

/// Reads CSV and Markdown files and turns them into flashcards.
enum FlashcardImporter {
    static let csvExtensions: Set<String> = ["csv", "tsv", "tab"]
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "mdx"]

    static let noCardsMessage =
        "No flashcards were found. Check that the file uses one of the supported formats (see “Supported Formats”)."

    /// Parses file contents, choosing the parser from the file extension.
    /// Files with other extensions (e.g. `.txt`) are tried as Markdown first, then as CSV.
    static func parse(text: String, fileName: String) -> ParsedFile {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let kind: SourceKind
        let result: ParseResult

        if csvExtensions.contains(fileExtension) {
            kind = .csv
            result = CSVParser.parse(text, delimiter: fileExtension == "csv" ? nil : "\t")
        } else if markdownExtensions.contains(fileExtension) {
            kind = .markdown
            result = MarkdownParser.parse(text)
        } else {
            let markdown = MarkdownParser.parse(text)
            if markdown.cards.isEmpty {
                kind = .csv
                result = CSVParser.parse(text)
            } else {
                kind = .markdown
                result = markdown
            }
        }

        return ParsedFile(
            fileName: fileName,
            kind: kind,
            cards: result.cards,
            skipped: result.skipped,
            errorMessage: result.cards.isEmpty ? noCardsMessage : nil
        )
    }

    /// Parses the file at `url`. Errors are reported in the returned `ParsedFile`.
    static func parseFile(at url: URL) -> ParsedFile {
        do {
            let text = try readText(from: url)
            return parse(text: text, fileName: url.lastPathComponent)
        } catch {
            let isCSV = csvExtensions.contains(url.pathExtension.lowercased())
            return ParsedFile(
                fileName: url.lastPathComponent,
                kind: isCSV ? .csv : .markdown,
                cards: [],
                errorMessage: "The file couldn’t be read: \(error.localizedDescription)"
            )
        }
    }

    enum ReadError: LocalizedError {
        case unsupportedEncoding

        var errorDescription: String? {
            "The file isn’t a text file, or uses an unsupported text encoding."
        }
    }

    /// Decodes text files saved as UTF-8 (with or without BOM), UTF-16, Windows-1252 or Latin-1.
    static func decodeText(_ data: Data) throws -> String {
        let bytes = [UInt8](data.prefix(3))
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]),
           let text = String(data: data, encoding: .utf16) {
            return text.strippingByteOrderMark
        }
        if let text = String(data: data, encoding: .utf8) {
            return text.strippingByteOrderMark
        }
        // Binary files usually contain NUL bytes; text files never do.
        guard !data.contains(0) else { throw ReadError.unsupportedEncoding }
        if let text = String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .isoLatin1) {
            return text
        }
        throw ReadError.unsupportedEncoding
    }

    static func readText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return try decodeText(data)
    }
}
