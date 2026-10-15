import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let flashiesModule = UTType(exportedAs: ModuleArchive.formatIdentifier, conformingTo: .json)
}

struct ModuleDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.flashiesModule] }
    let data: Data

    init(archive: ModuleArchive) throws { data = try archive.encoded() }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw ModuleArchive.ArchiveError.invalidFile }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func readModule(at url: URL) throws -> ModuleArchive {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
        return try ModuleArchive.decode(Data(contentsOf: url))
    }
}
