import Foundation

/// The parsed contents of one imported file.
struct ParsedFile: Identifiable, Sendable {
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
            errorMessage: result.errorMessage ?? (result.cards.isEmpty ? noCardsMessage : nil)
        )
    }

    /// Parses the file at `url`. Errors are reported in the returned `ParsedFile`.
    static func parseFile(at url: URL) -> ParsedFile {
        let ext = url.pathExtension.lowercased()
        guard csvExtensions.contains(ext) || markdownExtensions.contains(ext) || ext == "txt" || ext.isEmpty else {
            return ParsedFile(fileName: url.lastPathComponent, kind: .csv, cards: [],
                              errorMessage: "Choose a CSV, TSV, Markdown or plain text file. For Excel or Numbers workbooks, export the sheet as CSV first.")
        }
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
        let bytes = [UInt8](data.prefix(4))
        if bytes.starts(with: [0xFF, 0xFE, 0x00, 0x00]) || bytes.starts(with: [0x00, 0x00, 0xFE, 0xFF]),
           let text = String(data: data, encoding: .utf32), !text.contains("\0") {
            return text.strippingByteOrderMark
        }
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]),
           let text = String(data: data, encoding: .utf16) {
            return text.strippingByteOrderMark
        }
        // BOM-less UTF-16 spreadsheet exports can also be valid UTF-8 bytes, with
        // embedded NULs. Recognise their alternating NUL pattern before UTF-8.
        if data.count.isMultiple(of: 2), data.count >= 4 {
            let sample = Array(data.prefix(512))
            let pairs = sample.count / 2
            let evenZeros = stride(from: 0, to: pairs * 2, by: 2).filter { sample[$0] == 0 }.count
            let oddZeros = stride(from: 1, to: pairs * 2, by: 2).filter { sample[$0] == 0 }.count
            let encoding: String.Encoding? = oddZeros > pairs / 2 && evenZeros == 0 ? .utf16LittleEndian
                : evenZeros > pairs / 2 && oddZeros == 0 ? .utf16BigEndian : nil
            if let encoding, let text = String(data: data, encoding: encoding),
               !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && !CharacterSet.whitespacesAndNewlines.contains($0) }) {
                return text
            }
        }
        if let text = String(data: data, encoding: .utf8), !text.contains("\0") {
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
        var result: Result<Data, Error>?
        var coordinationError: NSError?
        // File coordination lets Files providers materialise cloud documents before reading.
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readableURL in
            result = Result { try Data(contentsOf: readableURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        let data = try result.get()
        return try decodeText(data)
    }
}
