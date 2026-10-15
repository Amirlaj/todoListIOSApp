import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let flashiesChapter = UTType(exportedAs: ChapterArchive.formatIdentifier, conformingTo: .json)
}

/// Immutable export snapshots keep SwiftData models out of file-writing callbacks.
struct ChapterDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.flashiesChapter, .commaSeparatedText] }

    let data: Data

    init(archive: ChapterArchive, asCSV: Bool = false) throws {
        data = try asCSV ? Data(archive.csv.utf8) : archive.encoded()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw ChapterArchive.ArchiveError.invalidFile
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func readChapter(at url: URL) throws -> ChapterArchive {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
        return try ChapterArchive.decode(Data(contentsOf: url))
    }
}
