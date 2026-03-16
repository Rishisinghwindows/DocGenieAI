import Foundation
import SwiftData

@MainActor
final class SharedFileImportService {
    static let shared = SharedFileImportService()
    private let storage = FileStorageService.shared
    private let metadata = FileMetadataService.shared

    private init() {}

    func checkAndImportSharedFiles(context: ModelContext) {
        let defaults = UserDefaults(suiteName: "group.com.docgenieai.shared")
        guard defaults?.bool(forKey: "hasNewSharedFiles") == true else { return }

        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.docgenieai.shared") else { return }
        let sharedDir = containerURL.appendingPathComponent("SharedFiles")

        guard let files = try? FileManager.default.contentsOfDirectory(at: sharedDir, includingPropertiesForKeys: nil) else { return }

        for fileURL in files {
            do {
                let result = try storage.importFile(from: fileURL)
                let meta = metadata.extractMetadata(from: result.url)
                let fileName = (result.url.lastPathComponent as NSString).deletingPathExtension
                let ext = result.url.pathExtension.lowercased()

                let docFile = DocumentFile(
                    name: fileName,
                    fileExtension: ext,
                    relativeFilePath: result.relativePath,
                    fileSize: meta.fileSize,
                    pageCount: meta.pageCount,
                    originalCreatedAt: meta.createdAt,
                    originalModifiedAt: meta.modifiedAt
                )
                context.insert(docFile)

                // Clean up shared file
                try? FileManager.default.removeItem(at: fileURL)

                // Background OCR
                let url = result.url
                Task {
                    if let text = try? await OCRService.shared.extractText(from: url),
                       !text.isEmpty {
                        docFile.ocrTextCache = String(text.prefix(5000))
                        let cat = AutoCategorizeService.shared.categorize(ocrText: text, fileName: docFile.name)
                        if cat.confidence >= 0.5, let tag = cat.suggestedTag, docFile.tagName == nil {
                            docFile.tagName = tag.rawValue
                        }
                        try? context.save()
                    }
                }
            } catch {
                continue
            }
        }

        try? context.save()
        defaults?.set(false, forKey: "hasNewSharedFiles")
        defaults?.removeObject(forKey: "sharedFileCount")
    }
}
