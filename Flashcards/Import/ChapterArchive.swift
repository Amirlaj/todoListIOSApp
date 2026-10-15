import Foundation

/// A versioned chapter file. Array order is the display order of cards and source files.
struct ChapterArchive: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let formatIdentifier = "com.amirlaj.Flashcards.chapter"

    struct Source: Codable, Equatable, Sendable {
        var id: UUID
        var fileName: String
        var kind: SourceKind
        var importedAt: Date
    }

    struct Card: Codable, Equatable, Sendable {
        var front: String
        var back: String
        var createdAt: Date
        var sourceID: UUID?
        var box: Int
        var timesCorrect: Int
        var timesIncorrect: Int
        var lastReviewedAt: Date?
        // Optional additions preserve compatibility with the original chapter format.
        var dueAt: Date? = nil
        var isFavorite: Bool? = nil
        var tags: [String]? = nil
        var reviews: [Review]? = nil
    }

    struct Review: Codable, Equatable, Sendable {
        var reviewedAt: Date
        var wasCorrect: Bool
    }

    var format = formatIdentifier
    var version = currentVersion
    var name: String
    var createdAt: Date
    var sources: [Source]
    var cards: [Card]

    enum ArchiveError: LocalizedError {
        case invalidFile
        case unsupportedVersion(Int)
        case invalidContent

        var errorDescription: String? {
            switch self {
            case .invalidFile:
                "This is not a valid Flashies chapter file. Choose a .flashies file exported from the app."
            case .unsupportedVersion(let version):
                "This chapter uses file version \(version), which this app cannot read. Try updating Flashies."
            case .invalidContent:
                "This chapter contains incomplete cards or invalid study data. Export it again from the original app."
            }
        }
    }

    func validated() throws -> Self {
        guard format == Self.formatIdentifier else { throw ArchiveError.invalidFile }
        guard version == Self.currentVersion else { throw ArchiveError.unsupportedVersion(version) }
        let sourceIDs = Set(sources.map(\.id))
        guard !name.trimmed.isEmpty,
              sourceIDs.count == sources.count,
              sources.allSatisfy({ !$0.fileName.trimmed.isEmpty }),
              cards.allSatisfy({ card in
                  !card.front.trimmed.isEmpty && !card.back.trimmed.isEmpty
                      && (0...5).contains(card.box)
                      && (0...1_000_000_000).contains(card.timesCorrect)
                      && (0...1_000_000_000).contains(card.timesIncorrect)
                      && (card.sourceID.map { sourceIDs.contains($0) } ?? true)
              }) else {
            throw ArchiveError.invalidContent
        }
        return self
    }

    func encoded() throws -> Data {
        _ = try validated()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        // Check the header first so future schemas get a useful version error.
        struct Header: Decodable { let format: String; let version: Int }
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.format == formatIdentifier else { throw ArchiveError.invalidFile }
            guard header.version == currentVersion else { throw ArchiveError.unsupportedVersion(header.version) }
            return try decoder.decode(Self.self, from: data).validated()
        } catch let error as ArchiveError {
            throw error
        } catch {
            throw ArchiveError.invalidFile
        }
    }

    /// Quotes every field so commas, quotes and multiline Markdown survive export.
    var csv: String {
        func quoted(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return (["front,back"] + cards.map { "\(quoted($0.front)),\(quoted($0.back))" })
            .joined(separator: "\r\n") + "\r\n"
    }

    var suggestedFilename: String {
        let invalid = CharacterSet(charactersIn: "/\\:").union(.controlCharacters)
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? "Chapter" : String(cleaned.prefix(80))
    }
}
