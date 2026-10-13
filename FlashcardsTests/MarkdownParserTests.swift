import Testing
@testable import Flashcards

struct MarkdownParserTests {
    @Test func headingsBecomeQuestionsAndTitleIsSkipped() {
        let markdown = """
        # Cell Biology
        Notes for chapter 1.

        ## What is a cell?
        The basic unit of life.

        ## Mitochondria
        - Produces ATP
        - Has its own DNA

        ## Empty heading
        ### Nucleus ###
        Stores genetic material.
        """
        let result = MarkdownParser.parse(markdown)
        #expect(result.cards == [
            ParsedCard(front: "What is a cell?", back: "The basic unit of life."),
            ParsedCard(front: "Mitochondria", back: "- Produces ATP\n- Has its own DNA"),
            ParsedCard(front: "Nucleus", back: "Stores genetic material."),
        ])
    }

    @Test func singleLevelOneHeadingWithoutOthersIsACard() {
        let result = MarkdownParser.parse("# Osmosis\nMovement of water across a membrane.")
        #expect(result.cards == [ParsedCard(front: "Osmosis", back: "Movement of water across a membrane.")])
    }

    @Test func questionAnswerLabels() {
        let markdown = """
        Q: What is 2 + 2?
        A: 4

        **Q1:** Name the phases of mitosis.

        **A1:**
        - Prophase
        - Metaphase

        Question: Multi-line
        question?
        Answer: Yes.

        Front: Capital of France
        Back: Paris
        """
        let result = MarkdownParser.parse(markdown)
        #expect(result.cards == [
            ParsedCard(front: "What is 2 + 2?", back: "4"),
            ParsedCard(front: "Name the phases of mitosis.", back: "- Prophase\n- Metaphase"),
            ParsedCard(front: "Multi-line\nquestion?", back: "Yes."),
            ParsedCard(front: "Capital of France", back: "Paris"),
        ])
    }

    @Test func answerEndsAtHeadingOrRule() {
        let markdown = """
        ## Flashcard 1
        Q: First?
        A: One

        More detail.
        ---
        Trailing notes.
        ## Next
        Body
        """
        let result = MarkdownParser.parse(markdown)
        #expect(result.cards == [
            ParsedCard(front: "First?", back: "One\n\nMore detail."),
            ParsedCard(front: "Next", back: "Body"),
        ])
    }

    @Test func questionWithoutAnswerStaysInSection() {
        let result = MarkdownParser.parse("## Topic\nQ: no answer here\nSome text")
        #expect(result.cards == [ParsedCard(front: "Topic", back: "Q: no answer here\nSome text")])
    }

    @Test func inlineDoubleColonCards() {
        let markdown = """
        ## Vocabulary
        - perro :: dog
        gato::cat
        Use `std::vector` for arrays
        casa ::: house
        """
        let result = MarkdownParser.parse(markdown)
        #expect(result.cards == [
            ParsedCard(front: "perro", back: "dog"),
            ParsedCard(front: "gato", back: "cat"),
            ParsedCard(front: "casa", back: "house"),
        ])
    }

    @Test func multiLineQuestionMarkSeparator() {
        let markdown = """
        What are the three
        domains of life?
        ?
        Bacteria, Archaea
        and Eukarya

        Not part of the card.
        """
        let result = MarkdownParser.parse(markdown)
        #expect(result.cards == [
            ParsedCard(front: "What are the three\ndomains of life?", back: "Bacteria, Archaea\nand Eukarya"),
        ])
    }

    @Test func tables() {
        let markdown = """
        ## Organelles
        Some intro text.

        | Organelle | Function | Location |
        |-----------|:--------:|---------:|
        | Nucleus   | Holds DNA | Centre |
        | Ribosome  | Makes proteins | |
        | Empty | | |

        | Answer | Question |
        | --- | --- |
        | Paris | Capital of France? |
        """
        let result = MarkdownParser.parse(markdown)
        #expect(result.cards == [
            ParsedCard(front: "Nucleus", back: "Holds DNA\n\n**Location:** Centre"),
            ParsedCard(front: "Ribosome", back: "Makes proteins"),
            ParsedCard(front: "Capital of France?", back: "Paris"),
        ])
        #expect(result.skipped == 1)
    }

    @Test func glossaryLines() {
        let markdown = """
        ## Key Terms
        - **Cell**: The basic unit of life.
        - **Tissue:** A group of similar cells.
        * __Organ__ — Tissues working together.
        **Note** that this line is not a term.
        """
        let result = MarkdownParser.parse(markdown)
        #expect(result.cards == [
            ParsedCard(front: "Cell", back: "The basic unit of life."),
            ParsedCard(front: "Tissue", back: "A group of similar cells."),
            ParsedCard(front: "Organ", back: "Tissues working together."),
        ])
    }

    @Test func questionHeadingKeepsWholeBody() {
        let markdown = """
        ## What are the phases of mitosis?
        - **Prophase**: chromosomes condense
        - **Metaphase**: chromosomes line up
        """
        let result = MarkdownParser.parse(markdown)
        #expect(result.cards == [
            ParsedCard(
                front: "What are the phases of mitosis?",
                back: "- **Prophase**: chromosomes condense\n- **Metaphase**: chromosomes line up"
            ),
        ])
    }

    @Test func labelWordsAreNotGlossaryTerms() {
        let result = MarkdownParser.parse("## Osmosis\n**Definition:** Movement of water.")
        #expect(result.cards == [ParsedCard(front: "Osmosis", back: "**Definition:** Movement of water.")])
    }

    @Test func codeBlocksAreNotParsed() {
        let markdown = """
        ## Python list comprehension
        ```python
        # not a heading
        squares = [x * x for x in range(10)]
        a: int = 1  # Q: not a question
        ```
        """
        let result = MarkdownParser.parse(markdown)
        #expect(result.cards == [
            ParsedCard(
                front: "Python list comprehension",
                back: "```python\n# not a heading\nsquares = [x * x for x in range(10)]\na: int = 1  # Q: not a question\n```"
            ),
        ])
    }

    @Test func skipsFrontMatterAndHandlesCRLF() {
        let markdown = "---\r\ntitle: Notes\r\ntags: [bio]\r\n---\r\n## DNA\r\nDeoxyribonucleic acid\r\n"
        let result = MarkdownParser.parse(markdown)
        #expect(result.cards == [ParsedCard(front: "DNA", back: "Deoxyribonucleic acid")])
    }

    @Test func removesCommonIndentation() {
        let result = MarkdownParser.parse("Q: Indented?\nA:\n    line one\n      line two")
        #expect(result.cards == [ParsedCard(front: "Indented?", back: "line one\n  line two")])
    }

    @Test func lineHelpers() {
        #expect(MarkdownParser.heading(in: "### Title") == .init(level: 3, text: "Title"))
        #expect(MarkdownParser.heading(in: "## C#") == .init(level: 2, text: "C#"))
        #expect(MarkdownParser.heading(in: "#hashtag") == nil)
        #expect(MarkdownParser.heading(in: "####### seven") == nil)
        #expect(MarkdownParser.isThematicBreak("- - -"))
        #expect(!MarkdownParser.isThematicBreak("--"))
        #expect(MarkdownParser.stripListMarker("12. [x] done") == "done")
        #expect(MarkdownParser.label(in: "Quick: not a label") == nil)
        #expect(MarkdownParser.label(in: "A to Z: not a label") == nil)
        #expect(MarkdownParser.label(in: "*Q 2*: hi")?.text == "hi")
        #expect(MarkdownParser.tableCells("| a \\| b | c |") == ["a | b", "c"])
    }
}
