import Foundation

/// Turns Markdown notes into flashcards. Several common styles are recognised and can be mixed:
///
/// 1. **Headings** – a heading is the front, the text below it (up to the next heading) is the back.
///    A single top-level `# Title` is treated as the document title when other headings exist.
/// 2. **Q&A labels** – `Q:` / `A:` (also `Question:`/`Answer:`, `Front:`/`Back:`, `Term:`/`Definition:`,
///    optionally bold or numbered like `**Q1:**`). The answer runs until the next question,
///    heading or horizontal rule.
/// 3. **Inline cards** – `Front :: Back` on a single line.
/// 4. **Multi-line cards** – question lines, a line containing only `?`, then answer lines
///    (ending at a blank line).
/// 5. **Tables** – each row of a Markdown table is a card (header names like
///    `Term | Definition` pick the columns; extra columns are added to the back).
/// 6. **Glossary lines** – `- **Term**: definition` or `**Term:** definition`.
///
/// A section whose heading ends with `?` always uses its whole body as the answer.
/// Sections that contain explicit cards (styles 2–6) don't also become a heading card.
enum MarkdownParser {
    static func parse(_ text: String) -> ParseResult {
        var extractor = Extractor(lines: splitLines(text))
        return extractor.run()
    }

    static func splitLines(_ text: String) -> [String] {
        text.strippingByteOrderMark
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    // MARK: - Line classification

    struct Heading: Equatable {
        var level: Int
        var text: String
    }

    static func heading(in trimmedLine: String) -> Heading? {
        let level = trimmedLine.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else { return nil }
        let rest = trimmedLine.dropFirst(level)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        var text = rest.trimmed
        // Remove an optional closing sequence: "## Title ##"
        if let closingStart = text.lastIndex(where: { $0 != "#" }), closingStart < text.index(before: text.endIndex) {
            let candidate = text[...closingStart]
            if candidate.last == " " { text = candidate.trimmed }
        } else if text.allSatisfy({ $0 == "#" }) {
            text = ""
        }
        return Heading(level: level, text: text)
    }

    static func isThematicBreak(_ trimmedLine: String) -> Bool {
        let compact = trimmedLine.filter { $0 != " " && $0 != "\t" }
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    static func fenceMarker(in trimmedLine: String) -> String? {
        if trimmedLine.hasPrefix("```") { return "```" }
        if trimmedLine.hasPrefix("~~~") { return "~~~" }
        return nil
    }

    /// Removes a leading list marker (`- `, `* `, `+ `, `1. `, `1) `) and task checkbox.
    static func stripListMarker(_ trimmedLine: String) -> String {
        var rest = Substring(trimmedLine)
        if let first = rest.first, "-*+".contains(first), rest.dropFirst().first == " " {
            rest = rest.dropFirst(2)
        } else {
            let digits = rest.prefix(while: { $0.isASCII && $0.isNumber })
            let afterDigits = rest.dropFirst(digits.count)
            if !digits.isEmpty, let marker = afterDigits.first, marker == "." || marker == ")",
               afterDigits.dropFirst().first == " " {
                rest = afterDigits.dropFirst(2)
            }
        }
        for checkbox in ["[ ] ", "[x] ", "[X] "] where rest.hasPrefix(checkbox) {
            rest = rest.dropFirst(checkbox.count)
            break
        }
        return rest.trimmed
    }

    enum LabelKind {
        case question
        case answer
    }

    private static let labels: [(text: String, kind: LabelKind)] = [
        ("question", .question), ("definition", .answer), ("answer", .answer),
        ("front", .question), ("back", .answer), ("term", .question),
        ("ans", .answer), ("q", .question), ("a", .answer),
    ]

    /// Recognises `Q: …`, `**Answer:** …`, `A1: …`, `- Front: …` and similar labelled lines.
    static func label(in trimmedLine: String) -> (kind: LabelKind, text: String)? {
        var line = Substring(stripListMarker(trimmedLine))
        var emphasis = ""
        for marker in ["**", "__", "*", "_"] where line.hasPrefix(marker) {
            emphasis = marker
            line = line.dropFirst(marker.count)
            break
        }
        let lowercased = line.lowercased()
        for label in labels where lowercased.hasPrefix(label.text) {
            var rest = line.dropFirst(label.text.count)
            rest = rest.drop(while: { $0 == " " })
            rest = rest.drop(while: { $0.isASCII && $0.isNumber })
            rest = rest.drop(while: { $0 == " " })
            var emphasisClosed = false
            if !emphasis.isEmpty, rest.hasPrefix(emphasis) {
                rest = rest.dropFirst(emphasis.count)
                emphasisClosed = true
            }
            // "Term :: definition" is an inline card, not a label.
            guard rest.hasPrefix(":"), !rest.hasPrefix("::") else { continue }
            rest = rest.dropFirst()
            if !emphasis.isEmpty, !emphasisClosed, rest.hasPrefix(emphasis) {
                rest = rest.dropFirst(emphasis.count)
            }
            return (label.kind, rest.trimmed)
        }
        return nil
    }

    /// `Front :: Back` (also `:::`), ignoring `::` inside inline code.
    static func inlineCard(in trimmedLine: String) -> ParsedCard? {
        let content = stripListMarker(trimmedLine)
        var inCode = false
        var index = content.startIndex
        while index < content.endIndex {
            let character = content[index]
            if character == "`" {
                inCode.toggle()
            } else if !inCode, content[index...].hasPrefix("::") {
                let front = content[..<index].trimmed
                var back = content[content.index(index, offsetBy: 2)...]
                if back.hasPrefix(":") { back = back.dropFirst() }
                let backText = back.trimmed
                guard !front.isEmpty, !backText.isEmpty else { return nil }
                return ParsedCard(front: front, back: backText)
            }
            index = content.index(after: index)
        }
        return nil
    }

    /// `- **Term**: definition`, `**Term:** definition`, `**Term** — definition`.
    static func glossaryCard(in trimmedLine: String) -> ParsedCard? {
        var rest = Substring(stripListMarker(trimmedLine))
        guard let marker = ["**", "__"].first(where: { rest.hasPrefix($0) }) else { return nil }
        rest = rest.dropFirst(marker.count)
        guard let closing = rest.range(of: marker) else { return nil }
        var term = rest[..<closing.lowerBound].trimmed
        var definition = rest[closing.upperBound...].trimmed
        var hasSeparator = false
        if term.hasSuffix(":") {
            term = String(term.dropLast()).trimmed
            hasSeparator = true
        }
        if definition.hasPrefix(":") {
            definition = definition.dropFirst().trimmed
            hasSeparator = true
        } else if !hasSeparator, let dash = ["—", "–", "-", "="].first(where: { definition.hasPrefix($0) }) {
            definition = definition.dropFirst(dash.count).trimmed
            hasSeparator = true
        }
        guard hasSeparator, !term.isEmpty, !definition.isEmpty else { return nil }
        return ParsedCard(front: term, back: definition)
    }

    static func isTableSeparator(_ trimmedLine: String) -> Bool {
        guard trimmedLine.contains("-"), trimmedLine.contains("|") else { return false }
        return trimmedLine.allSatisfy { "|-: \t".contains($0) }
    }

    static func tableCells(_ trimmedLine: String) -> [String] {
        var line = Substring(trimmedLine)
        if line.hasPrefix("|") { line = line.dropFirst() }
        if line.hasSuffix("|"), !line.hasSuffix("\\|") { line = line.dropLast() }
        var cells: [String] = []
        var cell = ""
        var previous: Character?
        for character in line {
            if character == "|", previous != "\\" {
                cells.append(cell)
                cell = ""
            } else if character == "|" {
                cell.removeLast()
                cell.append(character)
            } else {
                cell.append(character)
            }
            previous = character
        }
        cells.append(cell)
        return cells.map(\.trimmed)
    }

    /// Joins block lines into card text: removes surrounding blank lines, collapses repeated blank
    /// lines and removes common indentation.
    static func cleanBlock(_ lines: [String]) -> String {
        var output: [String] = []
        var previousWasBlank = false
        for line in lines {
            if line.trimmed.isEmpty {
                if !output.isEmpty, !previousWasBlank { output.append("") }
                previousWasBlank = true
            } else {
                var line = line
                while let last = line.last, last == " " || last == "\t" { line.removeLast() }
                output.append(line)
                previousWasBlank = false
            }
        }
        while output.last == "" { output.removeLast() }

        let indentation = output
            .filter { !$0.isEmpty }
            .map { $0.prefix(while: { $0 == " " }).count }
            .min() ?? 0
        if indentation > 0 {
            output = output.map { $0.isEmpty ? $0 : String($0.dropFirst(indentation)) }
        }
        return output.joined(separator: "\n").trimmed
    }
}

// MARK: - Extraction state machine

private extension MarkdownParser {
    struct Extractor {
        enum QAState {
            case none
            case question(lines: [String], raw: [String])
            case answer(question: [String], answer: [String])
        }

        let lines: [String]
        var result = ParseResult()

        var titleLineIndex: Int?
        var sectionTitle: String?
        var sectionIsDocumentTitle = false
        var sectionIsQuestion = false
        var sectionBody: [String] = []
        var sectionHasExplicitCards = false

        var qa = QAState.none
        var separatorCard: (question: [String], answer: [String])?
        var openFence: String?

        init(lines: [String]) {
            self.lines = lines
        }

        mutating func run() -> ParseResult {
            let start = frontMatterEnd()
            titleLineIndex = documentTitleLine(from: start)

            var index = start
            while index < lines.count {
                index = process(lineAt: index)
            }
            finishSection()
            return result
        }

        /// Handles the line at `index` and returns the index of the next line to process.
        private mutating func process(lineAt index: Int) -> Int {
            let line = lines[index]
            let trimmed = line.trimmed

            if let fence = openFence {
                appendToCurrentBlock(line)
                if trimmed.hasPrefix(fence) { openFence = nil }
                return index + 1
            }
            if let fence = MarkdownParser.fenceMarker(in: trimmed) {
                openFence = fence
                appendToCurrentBlock(line)
                return index + 1
            }
            if let heading = MarkdownParser.heading(in: trimmed) {
                finishSection()
                sectionTitle = heading.text
                sectionIsDocumentTitle = index == titleLineIndex
                sectionIsQuestion = heading.text.trimmingCharacters(in: CharacterSet(charactersIn: "*_ ")).hasSuffix("?")
                return index + 1
            }
            if sectionIsQuestion {
                sectionBody.append(line)
                return index + 1
            }
            if MarkdownParser.isThematicBreak(trimmed) {
                finishPendingCards()
                return index + 1
            }

            let label = MarkdownParser.label(in: trimmed)
            if let label {
                switch (label.kind, qa) {
                case (.question, _):
                    finishPendingCards()
                    qa = .question(lines: label.text.isEmpty ? [] : [label.text], raw: [line])
                    return index + 1
                case let (.answer, .question(question, _)):
                    qa = .answer(question: question, answer: label.text.isEmpty ? [] : [label.text])
                    return index + 1
                default:
                    break
                }
            }

            switch qa {
            case let .question(question, raw):
                qa = .question(lines: question + [line], raw: raw + [line])
                return index + 1
            case let .answer(question, answer):
                qa = .answer(question: question, answer: answer + [line])
                return index + 1
            case .none:
                break
            }

            if var pending = separatorCard {
                if trimmed.isEmpty {
                    finishSeparatorCard()
                } else {
                    pending.answer.append(line)
                    separatorCard = pending
                }
                return index + 1
            }
            if trimmed == "?" || trimmed == "??" {
                let question = takeTrailingParagraph()
                if !question.isEmpty {
                    separatorCard = (question, [])
                    return index + 1
                }
            }

            if let end = parseTable(at: index) {
                return end
            }
            if let card = MarkdownParser.inlineCard(in: trimmed) {
                addExplicitCard(card)
                return index + 1
            }
            // Lines like "**Definition:** …" that use a Q&A label word are not glossary terms.
            if label == nil, let card = MarkdownParser.glossaryCard(in: trimmed) {
                addExplicitCard(card)
                return index + 1
            }

            sectionBody.append(line)
            return index + 1
        }

        private mutating func appendToCurrentBlock(_ line: String) {
            switch qa {
            case let .question(question, raw):
                qa = .question(lines: question + [line], raw: raw + [line])
            case let .answer(question, answer):
                qa = .answer(question: question, answer: answer + [line])
            case .none:
                if var pending = separatorCard {
                    pending.answer.append(line)
                    separatorCard = pending
                } else {
                    sectionBody.append(line)
                }
            }
        }

        private mutating func addExplicitCard(_ card: ParsedCard) {
            result.cards.append(card)
            sectionHasExplicitCards = true
        }

        private mutating func addExplicitCard(front: [String], back: [String]) {
            let frontText = MarkdownParser.cleanBlock(front)
            let backText = MarkdownParser.cleanBlock(back)
            if frontText.isEmpty || backText.isEmpty {
                result.skipped += 1
                sectionHasExplicitCards = true
            } else {
                addExplicitCard(ParsedCard(front: frontText, back: backText))
            }
        }

        private mutating func finishPendingCards() {
            switch qa {
            case let .answer(question, answer):
                addExplicitCard(front: question, back: answer)
            case let .question(_, raw):
                // A question label without an answer: keep the text as ordinary content.
                sectionBody.append(contentsOf: raw)
            case .none:
                break
            }
            qa = .none
            finishSeparatorCard()
        }

        private mutating func finishSeparatorCard() {
            guard let pending = separatorCard else { return }
            separatorCard = nil
            addExplicitCard(front: pending.question, back: pending.answer)
        }

        private mutating func finishSection() {
            finishPendingCards()
            if let title = sectionTitle, !sectionIsDocumentTitle, !sectionHasExplicitCards {
                let front = title.trimmed
                let back = MarkdownParser.cleanBlock(sectionBody)
                if !front.isEmpty, !back.isEmpty {
                    result.cards.append(ParsedCard(front: front, back: back))
                }
            }
            sectionTitle = nil
            sectionIsDocumentTitle = false
            sectionIsQuestion = false
            sectionBody = []
            sectionHasExplicitCards = false
        }

        /// Removes and returns the lines after the last blank line of the current section body.
        private mutating func takeTrailingParagraph() -> [String] {
            var paragraph: [String] = []
            while let last = sectionBody.last, !last.trimmed.isEmpty {
                paragraph.insert(sectionBody.removeLast(), at: 0)
            }
            return paragraph
        }

        /// Parses a Markdown table starting at `index`. Returns the index after the table, or nil.
        private mutating func parseTable(at index: Int) -> Int? {
            let headerLine = lines[index].trimmed
            guard headerLine.contains("|"), index + 1 < lines.count,
                  MarkdownParser.isTableSeparator(lines[index + 1].trimmed) else { return nil }
            let header = MarkdownParser.tableCells(headerLine)
            guard header.count >= 2 else { return nil }

            let mapping = ColumnMapping.fromHeader(header) ?? .positional(labels: header)
            var next = index + 2
            sectionHasExplicitCards = true
            while next < lines.count {
                let row = lines[next].trimmed
                guard !row.isEmpty, row.contains("|") else { break }
                if let card = mapping.card(from: MarkdownParser.tableCells(row)) {
                    result.cards.append(card)
                } else {
                    result.skipped += 1
                }
                next += 1
            }
            return next
        }

        /// Skips YAML front matter at the top of the file.
        private func frontMatterEnd() -> Int {
            guard lines.first?.trimmed == "---" else { return 0 }
            for index in lines.indices.dropFirst() where ["---", "..."].contains(lines[index].trimmed) {
                return index + 1
            }
            return 0
        }

        /// A lone level-1 heading at the start of a document with other headings is its title.
        private func documentTitleLine(from start: Int) -> Int? {
            var headings: [(index: Int, level: Int)] = []
            var fence: String?
            for index in lines.indices where index >= start {
                let trimmed = lines[index].trimmed
                if let open = fence {
                    if trimmed.hasPrefix(open) { fence = nil }
                    continue
                }
                if let marker = MarkdownParser.fenceMarker(in: trimmed) {
                    fence = marker
                    continue
                }
                if let heading = MarkdownParser.heading(in: trimmed) {
                    headings.append((index, heading.level))
                }
            }
            guard let first = headings.first, first.level == 1, headings.count > 1,
                  headings.filter({ $0.level == 1 }).count == 1 else { return nil }
            return first.index
        }
    }
}
