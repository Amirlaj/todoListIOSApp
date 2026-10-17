import Foundation
import Testing
@testable import Flashcards

struct CSVParserTests {
    @Test func usesFirstTwoColumnsWithoutHeader() {
        let result = CSVParser.parse("Mitochondria,Powerhouse of the cell\nNucleus,Holds DNA\n")
        #expect(result.cards == [
            ParsedCard(front: "Mitochondria", back: "Powerhouse of the cell"),
            ParsedCard(front: "Nucleus", back: "Holds DNA"),
        ])
        #expect(result.skipped == 0)
    }

    @Test func recognisesHeaderRowAndColumnOrder() {
        let csv = """
        id,definition,term
        1,Powerhouse of the cell,Mitochondria
        2,Holds DNA,Nucleus
        """
        let result = CSVParser.parse(csv)
        #expect(result.cards.map(\.front) == ["Mitochondria", "Nucleus"])
        #expect(result.cards.first?.back == "Powerhouse of the cell\n\n**Id:** 1")
    }

    @Test func handlesQuotedFieldsWithCommasNewlinesAndQuotes() {
        let csv = "front,back\n\"Phases of mitosis\",\"Prophase, metaphase,\nanaphase, telophase\"\n\"Say \"\"hi\"\"\",Hello\n"
        let result = CSVParser.parse(csv)
        #expect(result.cards == [
            ParsedCard(front: "Phases of mitosis", back: "Prophase, metaphase,\nanaphase, telophase"),
            ParsedCard(front: "Say \"hi\"", back: "Hello"),
        ])
    }

    @Test func handlesWindowsLineEndingsAndByteOrderMark() {
        let result = CSVParser.parse("\u{FEFF}Question,Answer\r\n2+2,4\r\n3+3,6\r\n")
        #expect(result.cards == [ParsedCard(front: "2+2", back: "4"), ParsedCard(front: "3+3", back: "6")])
    }

    @Test func detectsSemicolonAndTabDelimiters() {
        #expect(CSVParser.detectDelimiter(in: "Hund;dog\nKatze;cat, kitten") == ";")
        #expect(CSVParser.detectDelimiter(in: "Hund\tdog, hound\nKatze\tcat, kitten") == "\t")
        #expect(CSVParser.detectDelimiter(in: "a,b; c\nd,e; f; g") == ",")

        let result = CSVParser.parse("Hund;dog\nKatze;cat")
        #expect(result.cards == [ParsedCard(front: "Hund", back: "dog"), ParsedCard(front: "Katze", back: "cat")])
    }

    @Test func singleLetterRowIsDataUnlessBothColumnsAreNamed() {
        #expect(CSVParser.parse("a,un\nb,deux").cards.count == 2)
        #expect(CSVParser.parse("Q,A\n2+2,4").cards == [ParsedCard(front: "2+2", back: "4")])
    }

    @Test func skipsIncompleteRowsAndBlankLines() {
        let result = CSVParser.parse("front,back\nonly a front,\n\n,only a back\nok,fine\n")
        #expect(result.cards == [ParsedCard(front: "ok", back: "fine")])
        #expect(result.skipped == 2)
    }

    @Test func convertsHTMLLineBreaks() {
        let result = CSVParser.parse("Primary colours,Red<br>Yellow<br/>Blue")
        #expect(result.cards.first?.back == "Red\nYellow\nBlue")
    }

    @Test func honoursExcelSeparatorDirectiveWithoutCreatingACardForIt() {
        let result = CSVParser.parse("\u{FEFF}sep=;\r\nQuestion;Answer\r\nWhat is Σ?;A finite alphabet, e.g. {a, b}\r\n")
        #expect(result.cards == [ParsedCard(front: "What is Σ?", back: "A finite alphabet, e.g. {a, b}")])
        #expect(result.skipped == 0)
        #expect(result.errorMessage == nil)
        #expect(CSVParser.parse("sep=\t\nfront\tback\na\tb").cards == [ParsedCard(front: "a", back: "b")])
    }

    @Test func headerWinsOverPunctuationInIncompleteRows() {
        let result = CSVParser.parse("front;back\nDFA;States, symbols, transitions\nAn incomplete row, with commas\nNFA;Zero, one or many choices")
        #expect(result.cards == [
            ParsedCard(front: "DFA", back: "States, symbols, transitions"),
            ParsedCard(front: "NFA", back: "Zero, one or many choices"),
        ])
        #expect(result.skipped == 1)
    }

    @Test func unclosedQuoteReportsAnErrorInsteadOfCombiningTheRemainingCards() {
        let file = FlashcardImporter.parse(text: "front,back\nDFA,\"A finite automaton\nNFA,Another automaton", fileName: "broken.csv")
        #expect(file.cards.isEmpty)
        #expect(file.errorMessage?.contains("closing quote") == true)
    }
}

struct FlashcardImporterTests {
    @Test func picksParserFromExtension() {
        let csv = FlashcardImporter.parse(text: "a,b", fileName: "deck.CSV")
        #expect(csv.kind == .csv)
        #expect(csv.cards == [ParsedCard(front: "a", back: "b")])

        let tsv = FlashcardImporter.parse(text: "a, b\tc", fileName: "deck.tsv")
        #expect(tsv.cards == [ParsedCard(front: "a, b", back: "c")])

        let markdown = FlashcardImporter.parse(text: "Q: a\nA: b", fileName: "notes.md")
        #expect(markdown.kind == .markdown)
        #expect(markdown.cards == [ParsedCard(front: "a", back: "b")])
    }

    @Test func plainTextFallsBackToCSV() {
        let tabbed = FlashcardImporter.parse(text: "perro\tdog\ngato\tcat", fileName: "quizlet.txt")
        #expect(tabbed.kind == .csv)
        #expect(tabbed.cards.count == 2)

        let notes = FlashcardImporter.parse(text: "term :: definition", fileName: "notes.txt")
        #expect(notes.kind == .markdown)
    }

    @Test func reportsFilesWithoutCards() {
        let file = FlashcardImporter.parse(text: "Just a paragraph of notes.", fileName: "notes.md")
        #expect(file.cards.isEmpty)
        #expect(file.errorMessage != nil)
    }

    @Test func decodesCommonEncodings() throws {
        let utf8BOM = Data([0xEF, 0xBB, 0xBF]) + Data("café,coffee".utf8)
        #expect(try FlashcardImporter.decodeText(utf8BOM) == "café,coffee")

        let latin1 = Data([0x63, 0x61, 0x66, 0xE9])  // "café" in Windows-1252
        #expect(try FlashcardImporter.decodeText(latin1) == "café")

        #expect(throws: FlashcardImporter.ReadError.self) {
            try FlashcardImporter.decodeText(Data([0x00, 0xFF, 0x10, 0x81]))
        }
    }

    @Test func duplicateKeyIgnoresCaseAndWhitespace() {
        let a = ParsedCard(front: "What is  DNA?", back: "Genetic\nmaterial")
        let b = ParsedCard(front: "what is DNA?", back: "genetic material ")
        #expect(a.duplicateKey == b.duplicateKey)
    }

    @Test func importsUTF16SpreadsheetExportsWithAndWithoutBOM() throws {
        let text = "Question\tAnswer\r\nWhat is ε?\tThe empty string\r\nWhat is Σ?\tAn alphabet\r\n"
        for encoding: String.Encoding in [.utf16, .utf16LittleEndian, .utf16BigEndian, .utf32] {
            let bytes = try #require(text.data(using: encoding))
            let decoded = try FlashcardImporter.decodeText(bytes)
            let file = FlashcardImporter.parse(text: decoded, fileName: "excel.csv")
            #expect(file.cards == [
                ParsedCard(front: "What is ε?", back: "The empty string"),
                ParsedCard(front: "What is Σ?", back: "An alphabet"),
            ])
        }
    }

    @Test func coordinatesPickedCSVReadAndPreservesMultilineUnicode() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).csv")
        defer { try? FileManager.default.removeItem(at: url) }
        // Use the same escaping as an actual spreadsheet CSV export.
        let validCSV = "front,back\r\n\"Define ε\",\"Empty string\nLength: 0\"\r\n\"Explain \"\"union\"\"\",\"R ∪ S\""
        try Data(validCSV.utf8).write(to: url)
        let file = FlashcardImporter.parsePickedFile(at: url)
        #expect(file.errorMessage == nil)
        #expect(file.cards == [
            ParsedCard(front: "Define ε", back: "Empty string\nLength: 0"),
            ParsedCard(front: "Explain \"union\"", back: "R ∪ S"),
        ])
    }

    @Test func givesActionableErrorForWorkbookSelectedInFiles() {
        let file = FlashcardImporter.parseFile(at: URL(fileURLWithPath: "/tmp/deck.xlsx"))
        #expect(file.cards.isEmpty)
        #expect(file.errorMessage?.contains("export the sheet as CSV") == true)
    }
}
