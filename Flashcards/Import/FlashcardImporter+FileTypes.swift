import Foundation
import UniformTypeIdentifiers

extension FlashcardImporter {
    /// Declared in Info.plist (UTImportedTypeDeclarations) so `.md` files can be picked.
    static let markdownType = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)

    /// File types offered in the document picker.
    static let allowedContentTypes: [UTType] = [
        .commaSeparatedText,
        .tabSeparatedText,
        .delimitedText,
        markdownType,
        .plainText,
    ]

    /// Parses a file returned by the document picker, which needs security-scoped access.
    static func parsePickedFile(at url: URL) -> ParsedFile {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        return parseFile(at: url)
    }
}
