import Foundation

struct ModuleArchive: Codable, Equatable, Sendable {
    static let formatIdentifier = "com.amirlaj.Flashcards.module"
    var format = formatIdentifier
    var version = 1
    var name: String
    var details: String
    var colorName: String
    var createdAt: Date
    var chapters: [ChapterArchive]

    enum ArchiveError: LocalizedError {
        case invalidFile
        case unsupportedVersion

        var errorDescription: String? {
            switch self {
            case .invalidFile: "This is not a valid Flashies module backup. Choose a .flashiesmodule file exported from the app."
            case .unsupportedVersion: "This module backup requires a newer version of Flashies. Update the app and try again."
            }
        }
    }

    func validated() throws -> Self {
        guard format == Self.formatIdentifier, !name.trimmed.isEmpty else { throw ArchiveError.invalidFile }
        guard version == 1 else { throw ArchiveError.unsupportedVersion }
        for chapter in chapters { _ = try chapter.validated() }
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
        struct Header: Decodable { let format: String; let version: Int }
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.format == formatIdentifier else { throw ArchiveError.invalidFile }
            guard header.version == 1 else { throw ArchiveError.unsupportedVersion }
            return try decoder.decode(Self.self, from: data).validated()
        } catch let error as ArchiveError {
            throw error
        } catch let error as ChapterArchive.ArchiveError {
            throw error
        } catch {
            throw ArchiveError.invalidFile
        }
    }

    var cardCount: Int { chapters.reduce(0) { $0 + $1.cards.count } }
    var suggestedFilename: String {
        ChapterArchive(name: name, createdAt: createdAt, sources: [], cards: []).suggestedFilename
    }
}
