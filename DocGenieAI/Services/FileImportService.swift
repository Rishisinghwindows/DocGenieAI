import Foundation
import SwiftData

@MainActor
final class FileImportService {
    private let storage = FileStorageService.shared
    private let metadata = FileMetadataService.shared

    func importFiles(from urls: [URL], into modelContext: ModelContext) throws -> [DocumentFile] {
        var importedFiles: [DocumentFile] = []

        for url in urls {
            let result = try storage.importFile(from: url)
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

            modelContext.insert(docFile)
            importedFiles.append(docFile)

            // Background OCR to populate search index
            let fileURL = result.url
            Task { @MainActor in
                if let text = try? await OCRService.shared.extractText(from: fileURL),
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    docFile.ocrTextCache = String(text.prefix(5000)) // Cap at 5KB per file

                    // Auto-categorize
                    let categorization = AutoCategorizeService.shared.categorize(ocrText: text, fileName: docFile.name)
                    if categorization.confidence >= 0.5, let suggestedTag = categorization.suggestedTag {
                        if docFile.tagName == nil { // Don't override user-set tags
                            docFile.tagName = suggestedTag.rawValue
                        }
                    }

                    try? modelContext.save()
                }
            }
        }

        try modelContext.save()

        // Sync widget data after import
        let descriptor = FetchDescriptor<DocumentFile>(sortBy: [SortDescriptor(\.importedAt, order: .reverse)])
        if let allFiles = try? modelContext.fetch(descriptor) {
            WidgetDataService.shared.syncAllWidgetData(allFiles: allFiles)
        }

        return importedFiles
    }
}
