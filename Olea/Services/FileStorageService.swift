import Foundation

final class FileStorageService: Sendable {
    static let shared = FileStorageService()

    let appFilesDirectory: URL
    let documentsDirectory: URL

    private init() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Documents directory not available")
        }
        let dir = docs.appendingPathComponent(AppConstants.appDocumentsSubdirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        documentsDirectory = docs
        appFilesDirectory = dir
    }

    func importFile(from sourceURL: URL) throws -> (url: URL, relativePath: String) {
        // Security scope is only needed when the picker hands us a non-copied
        // URL (asCopy: false) or a URL from the Files app. Calling
        // startAccessing on an already-copied temp URL just returns false and
        // is a no-op — harmless. Always call so both paths work.
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        // Force iCloud-backed files to download before we try to read them.
        // The Files app shows iCloud Drive PDFs as stubs until first access;
        // without this trigger, copyItem succeeds but copies a zero-byte file
        // (or fails with NSFileReadNoSuchFileError on iOS 26).
        try? FileManager.default.startDownloadingUbiquitousItem(at: sourceURL)

        let fileName = sourceURL.lastPathComponent
        var destinationURL = appFilesDirectory.appendingPathComponent(fileName)

        // Handle name collisions
        var counter = 1
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let newName = "\(nameWithoutExt) (\(counter)).\(ext)"
            destinationURL = appFilesDirectory.appendingPathComponent(newName)
            counter += 1
        }

        // Use NSFileCoordinator so iCloud / provider-backed files (Google Drive,
        // Dropbox, etc.) are materialized to a real on-disk path before we
        // read. Without coordinated access these can present as zero-byte
        // stubs and the copy silently writes garbage.
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var copyError: Error?

        coordinator.coordinate(
            readingItemAt: sourceURL,
            options: [.withoutChanges],
            error: &coordinationError
        ) { coordinatedURL in
            do {
                // Verify the source actually exists and is readable. If the
                // user picked a non-downloaded iCloud stub and the download
                // hasn't completed yet, fail loudly instead of writing a
                // zero-byte file.
                let attributes = try FileManager.default.attributesOfItem(atPath: coordinatedURL.path)
                let size = (attributes[.size] as? Int64) ?? 0
                guard size > 0 else {
                    copyError = FileStorageError.fileNotFound
                    return
                }
                try FileManager.default.copyItem(at: coordinatedURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let copyError {
            throw copyError
        }

        let relativePath = AppConstants.appDocumentsSubdirectory + "/" + destinationURL.lastPathComponent
        return (destinationURL, relativePath)
    }

    func deleteFile(at relativePath: String) throws {
        let url = documentsDirectory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func renameFile(at relativePath: String, to newName: String) throws -> String {
        let oldURL = documentsDirectory.appendingPathComponent(relativePath)
        let ext = oldURL.pathExtension
        let newFileName = "\(newName).\(ext)"
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newFileName)

        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            throw FileStorageError.nameAlreadyExists
        }

        try FileManager.default.moveItem(at: oldURL, to: newURL)
        return AppConstants.appDocumentsSubdirectory + "/" + newFileName
    }

    func fileExists(at relativePath: String) -> Bool {
        let url = documentsDirectory.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path)
    }
}

enum FileStorageError: LocalizedError {
    case nameAlreadyExists
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .nameAlreadyExists: return "A file with that name already exists."
        case .fileNotFound: return "File not found."
        }
    }
}
