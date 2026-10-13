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
}
