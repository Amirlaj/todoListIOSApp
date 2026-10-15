import SwiftUI

/// Renders the Markdown stored on a card: inline styles (bold, italic, code, links),
/// bullet lists, sub-headings and fenced code blocks.
enum MarkdownRenderer {
    private static let cache = NSCache<NSString, CacheEntry>()

    private final class CacheEntry {
        let value: AttributedString
        init(_ value: AttributedString) { self.value = value }
    }

    static func render(_ source: String) -> AttributedString {
        if let cached = cache.object(forKey: source as NSString) {
            return cached.value
        }
        let rendered = makeAttributedString(from: source)
        cache.setObject(CacheEntry(rendered), forKey: source as NSString)
        return rendered
    }

    private static func makeAttributedString(from source: String) -> AttributedString {
        var blocks: [AttributedString] = []
        var textLines: [String] = []
        var codeLines: [String] = []
        var openFence: String?

        func flushText() {
            guard !textLines.isEmpty else { return }
            blocks.append(inline(textLines.map(displayLine).joined(separator: "\n")))
            textLines = []
        }

        for line in source.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let fence = openFence {
                if trimmed.hasPrefix(fence) {
                    var code = AttributedString(codeLines.joined(separator: "\n"))
                    code[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = Font.system(.callout, design: .monospaced)
                    blocks.append(code)
                    codeLines = []
                    openFence = nil
                } else {
                    codeLines.append(line)
                }
            } else if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushText()
                openFence = String(trimmed.prefix(3))
            } else {
                textLines.append(line)
            }
        }
        if openFence != nil {
            textLines.append(contentsOf: codeLines)
        }
        flushText()

        var result = AttributedString()
        for (index, block) in blocks.enumerated() {
            if index > 0 { result.append(AttributedString("\n")) }
            result.append(block)
        }
        return result
    }

    private static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    /// Converts block-level Markdown that inline parsing doesn't understand into readable text.
    private static func displayLine(_ line: String) -> String {
        let indentation = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
        let content = line.dropFirst(indentation.count)

        if MarkdownParser.isThematicBreak(String(content)) {
            return "———"
        }
        for (checkbox, symbol) in [("- [ ] ", "☐ "), ("- [x] ", "☑ "), ("- [X] ", "☑ ")] where content.hasPrefix(checkbox) {
            return indentation + symbol + String(content.dropFirst(checkbox.count))
        }
        if let marker = content.first, "-*+".contains(marker), content.dropFirst().first == " " {
            return indentation + "• " + String(content.dropFirst(2))
        }
        if let heading = MarkdownParser.heading(in: String(content)), !heading.text.isEmpty {
            return "**\(heading.text)**"
        }
        if content.hasPrefix("> ") {
            return indentation + "▎ " + String(content.dropFirst(2))
        }
        return line
    }
}

/// Text that displays card Markdown.
struct MarkdownText: View {
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        Text(MarkdownRenderer.render(source))
    }
}

#if DEBUG
#Preview("Markdown", traits: .sizeThatFitsLayout) {
    MarkdownText("""
    # Cell Structure
    A cell is the **basic unit of life**. Some organisms are *unicellular*.

    - **Nucleus**: Stores DNA
    - **Mitochondria**: Produce ATP

    > Cells come from pre-existing cells.

    Use `cell.count` to count cells.

    ```swift
    let cells = ["Plant", "Animal"]
    ```
    """)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
}
#endif
