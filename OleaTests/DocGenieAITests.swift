import XCTest
import UIKit
import PDFKit
@testable import Olea

// MARK: - Model Tests

final class FileCategoryTests: XCTestCase {

    func testFromExtension_pdf() {
        XCTAssertEqual(FileCategory.from(extension: "pdf"), .pdf)
    }

    func testFromExtension_doc() {
        XCTAssertEqual(FileCategory.from(extension: "doc"), .doc)
        XCTAssertEqual(FileCategory.from(extension: "docx"), .doc)
    }

    func testFromExtension_xls() {
        XCTAssertEqual(FileCategory.from(extension: "xls"), .xls)
        XCTAssertEqual(FileCategory.from(extension: "xlsx"), .xls)
    }

    func testFromExtension_ppt() {
        XCTAssertEqual(FileCategory.from(extension: "ppt"), .ppt)
        XCTAssertEqual(FileCategory.from(extension: "pptx"), .ppt)
    }

    func testFromExtension_txt() {
        XCTAssertEqual(FileCategory.from(extension: "txt"), .txt)
        XCTAssertEqual(FileCategory.from(extension: "csv"), .txt)
        XCTAssertEqual(FileCategory.from(extension: "xml"), .txt)
        XCTAssertEqual(FileCategory.from(extension: "rtf"), .txt)
    }

    func testFromExtension_img() {
        XCTAssertEqual(FileCategory.from(extension: "jpg"), .img)
        XCTAssertEqual(FileCategory.from(extension: "jpeg"), .img)
        XCTAssertEqual(FileCategory.from(extension: "png"), .img)
        XCTAssertEqual(FileCategory.from(extension: "heic"), .img)
        XCTAssertEqual(FileCategory.from(extension: "webp"), .img)
        XCTAssertEqual(FileCategory.from(extension: "bmp"), .img)
        XCTAssertEqual(FileCategory.from(extension: "gif"), .img)
        XCTAssertEqual(FileCategory.from(extension: "tiff"), .img)
    }

    func testFromExtension_caseInsensitive() {
        XCTAssertEqual(FileCategory.from(extension: "PDF"), .pdf)
        XCTAssertEqual(FileCategory.from(extension: "Jpg"), .img)
        XCTAssertEqual(FileCategory.from(extension: "DOCX"), .doc)
    }

    func testFromExtension_unknown_returnsAll() {
        XCTAssertEqual(FileCategory.from(extension: "zip"), .all)
        XCTAssertEqual(FileCategory.from(extension: "mp4"), .all)
        XCTAssertEqual(FileCategory.from(extension: ""), .all)
    }

    func testAllCasesCount() {
        XCTAssertEqual(FileCategory.allCases.count, 7)
    }

    func testLabels() {
        XCTAssertEqual(FileCategory.all.label, "All")
        XCTAssertEqual(FileCategory.pdf.label, "PDF")
        XCTAssertEqual(FileCategory.doc.label, "Doc")
        XCTAssertEqual(FileCategory.xls.label, "XLS")
        XCTAssertEqual(FileCategory.ppt.label, "PPT")
        XCTAssertEqual(FileCategory.txt.label, "TXT")
        XCTAssertEqual(FileCategory.img.label, "IMG")
    }

    func testSystemImages() {
        XCTAssertFalse(FileCategory.pdf.systemImage.isEmpty)
        XCTAssertFalse(FileCategory.doc.systemImage.isEmpty)
        XCTAssertFalse(FileCategory.img.systemImage.isEmpty)
    }

    func testExtensions_pdfOnly() {
        XCTAssertEqual(FileCategory.pdf.extensions, ["pdf"])
    }

    func testExtensions_all_containsAllSupported() {
        let allExtensions = FileCategory.all.extensions
        XCTAssertTrue(allExtensions.contains("pdf"))
        XCTAssertTrue(allExtensions.contains("docx"))
        XCTAssertTrue(allExtensions.contains("jpg"))
        XCTAssertTrue(allExtensions.contains("txt"))
    }

    func testIdentifiable() {
        XCTAssertEqual(FileCategory.pdf.id, "pdf")
        XCTAssertEqual(FileCategory.all.id, "all")
    }
}

final class ViewerTypeTests: XCTestCase {

    func testFromExtension_pdf() {
        XCTAssertEqual(ViewerType.from(extension: "pdf"), .pdf)
    }

    func testFromExtension_images() {
        XCTAssertEqual(ViewerType.from(extension: "jpg"), .image)
        XCTAssertEqual(ViewerType.from(extension: "jpeg"), .image)
        XCTAssertEqual(ViewerType.from(extension: "png"), .image)
        XCTAssertEqual(ViewerType.from(extension: "heic"), .image)
        XCTAssertEqual(ViewerType.from(extension: "webp"), .image)
        XCTAssertEqual(ViewerType.from(extension: "bmp"), .image)
        XCTAssertEqual(ViewerType.from(extension: "gif"), .image)
        XCTAssertEqual(ViewerType.from(extension: "tiff"), .image)
    }

    func testFromExtension_quickLook() {
        XCTAssertEqual(ViewerType.from(extension: "docx"), .quickLook)
        XCTAssertEqual(ViewerType.from(extension: "xlsx"), .quickLook)
        XCTAssertEqual(ViewerType.from(extension: "pptx"), .quickLook)
        XCTAssertEqual(ViewerType.from(extension: "txt"), .quickLook)
    }

    func testFromExtension_caseInsensitive() {
        XCTAssertEqual(ViewerType.from(extension: "PDF"), .pdf)
        XCTAssertEqual(ViewerType.from(extension: "PNG"), .image)
    }

    func testEquatable() {
        XCTAssertEqual(ViewerType.pdf, ViewerType.pdf)
        XCTAssertNotEqual(ViewerType.pdf, ViewerType.image)
        XCTAssertNotEqual(ViewerType.image, ViewerType.quickLook)
    }
}

final class ToolItemTests: XCTestCase {

    func testAllCasesCount() {
        // 29 PDF tools + 1 Smart Form Fill = 30
        XCTAssertEqual(ToolItem.allCases.count, 30)
    }

    func testIdentifiable() {
        XCTAssertEqual(ToolItem.scanner.id, "Scanner")
        XCTAssertEqual(ToolItem.mergePDF.id, "Merge PDF")
    }

    func testSystemImageNotEmpty() {
        for tool in ToolItem.allCases {
            XCTAssertFalse(tool.systemImage.isEmpty, "systemImage empty for \(tool.rawValue)")
        }
    }

    func testDescriptionNotEmpty() {
        for tool in ToolItem.allCases {
            XCTAssertFalse(tool.description.isEmpty, "description empty for \(tool.rawValue)")
        }
    }

    func testRawValues() {
        XCTAssertEqual(ToolItem.scanner.rawValue, "Scanner")
        XCTAssertEqual(ToolItem.mergePDF.rawValue, "Merge PDF")
        XCTAssertEqual(ToolItem.splitPDF.rawValue, "Split PDF")
        XCTAssertEqual(ToolItem.compressPDF.rawValue, "Compress")
        XCTAssertEqual(ToolItem.lockPDF.rawValue, "Lock PDF")
        XCTAssertEqual(ToolItem.unlockPDF.rawValue, "Unlock PDF")
        XCTAssertEqual(ToolItem.extractPages.rawValue, "Extract Pages")
        XCTAssertEqual(ToolItem.rotatePDF.rawValue, "Rotate PDF")
        XCTAssertEqual(ToolItem.reorderPDF.rawValue, "Reorder Pages")
        XCTAssertEqual(ToolItem.pageNumbers.rawValue, "Page Numbers")
        XCTAssertEqual(ToolItem.watermark.rawValue, "Watermark")
        XCTAssertEqual(ToolItem.ocrText.rawValue, "OCR Text")
        XCTAssertEqual(ToolItem.imageToPDF.rawValue, "Image to PDF")
        XCTAssertEqual(ToolItem.docToPDF.rawValue, "Doc to PDF")
        XCTAssertEqual(ToolItem.pdfToImage.rawValue, "PDF to Image")
        XCTAssertEqual(ToolItem.pdfToText.rawValue, "PDF to Text")
        XCTAssertEqual(ToolItem.signPDF.rawValue, "Sign PDF")
        XCTAssertEqual(ToolItem.cropPDF.rawValue, "Crop PDF")
        XCTAssertEqual(ToolItem.metadataEditor.rawValue, "PDF Metadata")
        XCTAssertEqual(ToolItem.summarizePDF.rawValue, "Summarize PDF")
        XCTAssertEqual(ToolItem.askPDF.rawValue, "Ask PDF")
        XCTAssertEqual(ToolItem.translatePDF.rawValue, "Translate PDF")
        XCTAssertEqual(ToolItem.emailPDF.rawValue, "Email PDF")
    }

    func testNewToolSections() {
        XCTAssertEqual(ToolItem.signPDF.section, "Enhance")
        XCTAssertEqual(ToolItem.cropPDF.section, "Edit")
        XCTAssertEqual(ToolItem.metadataEditor.section, "Enhance")
        XCTAssertEqual(ToolItem.summarizePDF.section, "AI Intelligence")
        XCTAssertEqual(ToolItem.askPDF.section, "AI Intelligence")
        XCTAssertEqual(ToolItem.translatePDF.section, "AI Intelligence")
        XCTAssertEqual(ToolItem.emailPDF.section, "Share & Create")
    }

    func testNewToolIcons() {
        XCTAssertEqual(ToolItem.signPDF.systemImage, "signature")
        XCTAssertEqual(ToolItem.cropPDF.systemImage, "crop")
        XCTAssertEqual(ToolItem.metadataEditor.systemImage, "info.circle")
        XCTAssertEqual(ToolItem.summarizePDF.systemImage, "text.badge.star")
        XCTAssertEqual(ToolItem.askPDF.systemImage, "questionmark.bubble")
        XCTAssertEqual(ToolItem.translatePDF.systemImage, "textformat.abc")
        XCTAssertEqual(ToolItem.emailPDF.systemImage, "envelope")
    }
}

final class ScanFilterTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ScanFilter.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(ScanFilter.color.rawValue, "Color")
        XCTAssertEqual(ScanFilter.grayscale.rawValue, "Grayscale")
        XCTAssertEqual(ScanFilter.blackAndWhite.rawValue, "B&W")
        XCTAssertEqual(ScanFilter.sharpen.rawValue, "Sharp")
    }

    func testIdentifiable() {
        XCTAssertEqual(ScanFilter.color.id, "Color")
    }

    func testSystemImageNotEmpty() {
        for filter in ScanFilter.allCases {
            XCTAssertFalse(filter.systemImage.isEmpty, "systemImage empty for \(filter.rawValue)")
        }
    }
}

final class FileSortOptionTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(FileSortOption.allCases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(FileSortOption.dateDesc.rawValue, "Newest First")
        XCTAssertEqual(FileSortOption.dateAsc.rawValue, "Oldest First")
        XCTAssertEqual(FileSortOption.nameAsc.rawValue, "Name (A-Z)")
        XCTAssertEqual(FileSortOption.nameDesc.rawValue, "Name (Z-A)")
        XCTAssertEqual(FileSortOption.sizeDesc.rawValue, "Largest First")
        XCTAssertEqual(FileSortOption.sizeAsc.rawValue, "Smallest First")
        XCTAssertEqual(FileSortOption.typeAsc.rawValue, "Type (A-Z)")
    }

    func testIdentifiable() {
        XCTAssertEqual(FileSortOption.dateDesc.id, "Newest First")
    }
}

final class ScannedPageTests: XCTestCase {

    func testInit() {
        let image = UIImage(systemName: "doc")!
        let page = ScannedPage(image: image)

        XCTAssertNotNil(page.id)
        XCTAssertEqual(page.originalImage, image)
        XCTAssertEqual(page.currentImage, image)
        XCTAssertEqual(page.appliedFilter, .color)
        XCTAssertEqual(page.rotation, 0)
    }

    func testMutation() {
        let image = UIImage(systemName: "doc")!
        var page = ScannedPage(image: image)

        page.appliedFilter = .grayscale
        page.rotation = 90

        XCTAssertEqual(page.appliedFilter, .grayscale)
        XCTAssertEqual(page.rotation, 90)
        XCTAssertEqual(page.originalImage, image) // Original unchanged
    }
}

final class DocumentFileTests: XCTestCase {

    func testInit() {
        let file = DocumentFile(
            name: "Test",
            fileExtension: "pdf",
            relativeFilePath: "DocGenieFiles/Test.pdf",
            fileSize: 1024
        )

        XCTAssertNotNil(file.id)
        XCTAssertEqual(file.name, "Test")
        XCTAssertEqual(file.fileExtension, "pdf")
        XCTAssertEqual(file.relativeFilePath, "DocGenieFiles/Test.pdf")
        XCTAssertEqual(file.fileSize, 1024)
        XCTAssertNil(file.pageCount)
        XCTAssertFalse(file.isFavorite)
        XCTAssertNil(file.lastOpenedAt)
    }

    func testCategory() {
        let pdfFile = DocumentFile(name: "Doc", fileExtension: "pdf", relativeFilePath: "", fileSize: 0)
        XCTAssertEqual(pdfFile.category, .pdf)

        let imgFile = DocumentFile(name: "Photo", fileExtension: "jpg", relativeFilePath: "", fileSize: 0)
        XCTAssertEqual(imgFile.category, .img)

        let docFile = DocumentFile(name: "Word", fileExtension: "docx", relativeFilePath: "", fileSize: 0)
        XCTAssertEqual(docFile.category, .doc)
    }

    func testViewerType() {
        let pdfFile = DocumentFile(name: "Doc", fileExtension: "pdf", relativeFilePath: "", fileSize: 0)
        XCTAssertEqual(pdfFile.viewerType, .pdf)

        let imgFile = DocumentFile(name: "Photo", fileExtension: "png", relativeFilePath: "", fileSize: 0)
        XCTAssertEqual(imgFile.viewerType, .image)

        let docFile = DocumentFile(name: "Word", fileExtension: "docx", relativeFilePath: "", fileSize: 0)
        XCTAssertEqual(docFile.viewerType, .quickLook)
    }

    func testFullFileName() {
        let file = DocumentFile(name: "Report", fileExtension: "pdf", relativeFilePath: "", fileSize: 0)
        XCTAssertEqual(file.fullFileName, "Report.pdf")
    }

    func testFileURL() {
        let file = DocumentFile(
            name: "Test",
            fileExtension: "pdf",
            relativeFilePath: "DocGenieFiles/Test.pdf",
            fileSize: 0
        )
        XCTAssertNotNil(file.fileURL)
        XCTAssertTrue(file.fileURL!.path.contains("DocGenieFiles/Test.pdf"))
    }

    func testInitWithAllParameters() {
        let now = Date.now
        let file = DocumentFile(
            name: "Report",
            fileExtension: "pdf",
            relativeFilePath: "DocGenieFiles/Report.pdf",
            fileSize: 2048,
            pageCount: 5,
            importedAt: now,
            originalCreatedAt: now,
            originalModifiedAt: now,
            isFavorite: true
        )

        XCTAssertEqual(file.pageCount, 5)
        XCTAssertEqual(file.importedAt, now)
        XCTAssertEqual(file.originalCreatedAt, now)
        XCTAssertTrue(file.isFavorite)
    }
}

final class ChatMessageTests: XCTestCase {

    func testInit() {
        let conv = Conversation()
        let msg = ChatMessage(content: "Hello", role: "user", conversation: conv)

        XCTAssertNotNil(msg.id)
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertEqual(msg.role, "user")
        XCTAssertEqual(msg.conversationId, conv.id)
        XCTAssertNil(msg.toolBadge)
    }

    func testIsUser() {
        let conv = Conversation()
        let userMsg = ChatMessage(content: "Hi", role: "user", conversation: conv)
        XCTAssertTrue(userMsg.isUser)
        XCTAssertFalse(userMsg.isAssistant)
    }

    func testIsAssistant() {
        let conv = Conversation()
        let aiMsg = ChatMessage(content: "Hello!", role: "assistant", conversation: conv)
        XCTAssertFalse(aiMsg.isUser)
        XCTAssertTrue(aiMsg.isAssistant)
    }

    func testToolBadge() {
        let conv = Conversation()
        let msg = ChatMessage(content: "Merging...", role: "assistant", conversation: conv, toolBadge: "Merge PDF")
        XCTAssertEqual(msg.toolBadge, "Merge PDF")
    }
}

final class ConversationTests: XCTestCase {

    func testDefaultInit() {
        let conv = Conversation()
        XCTAssertNotNil(conv.id)
        XCTAssertEqual(conv.title, "New Chat")
        XCTAssertNotNil(conv.createdAt)
        XCTAssertNotNil(conv.updatedAt)
    }

    func testCustomTitle() {
        let conv = Conversation(title: "PDF Help")
        XCTAssertEqual(conv.title, "PDF Help")
    }
}

// MARK: - Extension Tests

final class StringFileExtensionTests: XCTestCase {

    func testFileExtension() {
        XCTAssertEqual("document.pdf".fileExtension, "pdf")
        XCTAssertEqual("photo.JPG".fileExtension, "jpg")
        XCTAssertEqual("report.docx".fileExtension, "docx")
        XCTAssertEqual("noextension".fileExtension, "")
    }

    func testFileNameWithoutExtension() {
        XCTAssertEqual("document.pdf".fileNameWithoutExtension, "document")
        XCTAssertEqual("my.report.docx".fileNameWithoutExtension, "my.report")
        XCTAssertEqual("noextension".fileNameWithoutExtension, "noextension")
    }
}

final class Int64FileSizeTests: XCTestCase {

    func testFormattedFileSize_KB() {
        let size: Int64 = 1024
        let formatted = size.formattedFileSize
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("kB"))
    }

    func testFormattedFileSize_MB() {
        let size: Int64 = 5 * 1024 * 1024
        let formatted = size.formattedFileSize
        XCTAssertTrue(formatted.contains("MB"))
    }

    func testFormattedFileSize_zero() {
        let size: Int64 = 0
        let formatted = size.formattedFileSize
        XCTAssertFalse(formatted.isEmpty)
    }
}

final class DateFormattingTests: XCTestCase {

    func testRelativeDisplay_today() {
        let now = Date.now
        let display = now.relativeDisplay
        XCTAssertTrue(display.contains("Today"))
    }

    func testRelativeDisplay_yesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let display = yesterday.relativeDisplay
        XCTAssertTrue(display.contains("Yesterday"))
    }

    func testRelativeDisplay_thisWeek() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        let display = threeDaysAgo.relativeDisplay
        // Should be a weekday name, not "Today" or "Yesterday"
        XCTAssertFalse(display.contains("Today"))
        XCTAssertFalse(display.contains("Yesterday"))
        XCTAssertFalse(display.isEmpty)
    }

    func testRelativeDisplay_olderThanWeek() {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
        let display = monthAgo.relativeDisplay
        // Should contain a month abbreviation and year
        XCTAssertFalse(display.contains("Today"))
        XCTAssertFalse(display.contains("Yesterday"))
        XCTAssertFalse(display.isEmpty)
    }
}

// MARK: - Constants Tests

final class AppConstantsTests: XCTestCase {

    func testSupportedExtensions() {
        XCTAssertTrue(AppConstants.supportedExtensions.contains("pdf"))
        XCTAssertTrue(AppConstants.supportedExtensions.contains("docx"))
        XCTAssertTrue(AppConstants.supportedExtensions.contains("jpg"))
        XCTAssertTrue(AppConstants.supportedExtensions.contains("png"))
        XCTAssertTrue(AppConstants.supportedExtensions.contains("txt"))
        XCTAssertFalse(AppConstants.supportedExtensions.contains("zip"))
        XCTAssertFalse(AppConstants.supportedExtensions.contains("mp4"))
    }

    func testSupportedUTTypes() {
        XCTAssertFalse(AppConstants.supportedUTTypes.isEmpty)
    }

    func testMaxFileSizeBytes() {
        XCTAssertEqual(AppConstants.maxFileSizeBytes, 500 * 1024 * 1024)
    }

    func testAppDocumentsSubdirectory() {
        XCTAssertEqual(AppConstants.appDocumentsSubdirectory, "DocGenieFiles")
    }
}

// MARK: - Service Tests

final class FileStorageServiceTests: XCTestCase {
    let service = FileStorageService.shared

    func testDocumentsDirectoryExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.documentsDirectory.path))
    }

    func testAppFilesDirectoryCreated() {
        let dir = service.appFilesDirectory
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
    }

    func testFileExists_nonexistent() {
        XCTAssertFalse(service.fileExists(at: "DocGenieFiles/nonexistent_file_abc123.pdf"))
    }

    func testDeleteFile_nonexistent_noThrow() {
        // Deleting a nonexistent file should not throw
        XCTAssertNoThrow(try service.deleteFile(at: "DocGenieFiles/nonexistent_xyz.pdf"))
    }

    func testImportAndDeleteFile() throws {
        // Create a temporary file to import
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_import_\(UUID().uuidString).txt")
        try "Test content".write(to: tempFile, atomically: true, encoding: .utf8)

        // Import it
        let result = try service.importFile(from: tempFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        XCTAssertTrue(result.relativePath.hasPrefix(AppConstants.appDocumentsSubdirectory))

        // Clean up
        try service.deleteFile(at: result.relativePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.url.path))

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempFile)
    }

    func testImportFile_collisionHandling() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile1 = tempDir.appendingPathComponent("collision_test.txt")
        try "File 1".write(to: tempFile1, atomically: true, encoding: .utf8)

        let result1 = try service.importFile(from: tempFile1)

        // Create same-named temp file again
        try "File 2".write(to: tempFile1, atomically: true, encoding: .utf8)
        let result2 = try service.importFile(from: tempFile1)

        // Should have different paths (collision handling)
        XCTAssertNotEqual(result1.relativePath, result2.relativePath)
        XCTAssertTrue(result2.relativePath.contains("(1)"))

        // Clean up
        try service.deleteFile(at: result1.relativePath)
        try service.deleteFile(at: result2.relativePath)
        try? FileManager.default.removeItem(at: tempFile1)
    }

    func testRenameFile() throws {
        // Create a file first
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("rename_test.txt")
        try "Content".write(to: tempFile, atomically: true, encoding: .utf8)

        let result = try service.importFile(from: tempFile)
        let newRelativePath = try service.renameFile(at: result.relativePath, to: "renamed_file")

        XCTAssertTrue(newRelativePath.contains("renamed_file.txt"))
        XCTAssertTrue(service.fileExists(at: newRelativePath))
        XCTAssertFalse(service.fileExists(at: result.relativePath))

        // Clean up
        try service.deleteFile(at: newRelativePath)
        try? FileManager.default.removeItem(at: tempFile)
    }

    func testRenameFile_nameAlreadyExists() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile1 = tempDir.appendingPathComponent("existing_name.txt")
        let tempFile2 = tempDir.appendingPathComponent("to_rename.txt")
        try "A".write(to: tempFile1, atomically: true, encoding: .utf8)
        try "B".write(to: tempFile2, atomically: true, encoding: .utf8)

        let result1 = try service.importFile(from: tempFile1)
        let result2 = try service.importFile(from: tempFile2)

        // Try to rename file2 to same name as file1
        XCTAssertThrowsError(try service.renameFile(at: result2.relativePath, to: "existing_name")) { error in
            XCTAssertTrue(error is FileStorageError)
        }

        // Clean up
        try service.deleteFile(at: result1.relativePath)
        try service.deleteFile(at: result2.relativePath)
        try? FileManager.default.removeItem(at: tempFile1)
        try? FileManager.default.removeItem(at: tempFile2)
    }
}

final class FileMetadataServiceTests: XCTestCase {
    let service = FileMetadataService.shared

    func testExtractMetadata_textFile() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("meta_test_\(UUID().uuidString).txt")
        try "Hello metadata test".write(to: tempFile, atomically: true, encoding: .utf8)

        let metadata = service.extractMetadata(from: tempFile)
        XCTAssertGreaterThan(metadata.fileSize, 0)
        XCTAssertNil(metadata.pageCount) // Not a PDF
        XCTAssertNotNil(metadata.createdAt)
        XCTAssertNotNil(metadata.modifiedAt)

        try? FileManager.default.removeItem(at: tempFile)
    }
}

@MainActor
final class ScannerServiceTests: XCTestCase {
    let service = ScannerService.shared

    func testApplyFilter_color_returnsOriginal() {
        let image = UIImage(systemName: "doc")!
        let result = service.applyFilter(.color, to: image)
        XCTAssertEqual(result.size, image.size)
    }

    func testApplyFilter_grayscale() {
        let image = createTestImage()
        let result = service.applyFilter(.grayscale, to: image)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result.size.width, 0)
    }

    func testApplyFilter_blackAndWhite() {
        let image = createTestImage()
        let result = service.applyFilter(.blackAndWhite, to: image)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result.size.width, 0)
    }

    func testApplyFilter_sharpen() {
        let image = createTestImage()
        let result = service.applyFilter(.sharpen, to: image)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result.size.width, 0)
    }

    func testRotateImage() {
        let image = createTestImage()
        let rotated = service.rotateImage(image, by: 90)
        XCTAssertNotNil(rotated)
        // After 90 degree rotation, width and height swap approximately
        XCTAssertGreaterThan(rotated.size.width, 0)
        XCTAssertGreaterThan(rotated.size.height, 0)
    }

    func testGeneratePDF_emptyPages() {
        let data = service.generatePDF(from: [])
        // Empty pages produce a valid but empty PDF doc
        XCTAssertNotNil(data)
    }

    func testGeneratePDF_withPages() {
        let image = createTestImage()
        let page = ScannedPage(image: image)
        let data = service.generatePDF(from: [page])
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data!.count, 0)
    }

    func testSaveScanAsPDF() throws {
        let image = createTestImage()
        let page = ScannedPage(image: image)
        let result = try service.saveScanAsPDF(pages: [page], fileName: "test_scan_\(UUID().uuidString)")

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        XCTAssertTrue(result.relativePath.hasPrefix(AppConstants.appDocumentsSubdirectory))

        // Clean up
        try? FileManager.default.removeItem(at: result.url)
    }

    private func createTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }
}

@MainActor
final class PDFToolsServiceTests: XCTestCase {
    let service = PDFToolsService.shared

    private func createTestPDF(pageCount: Int = 3) throws -> URL {
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 300))
        for i in 0..<pageCount {
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
                let text = "Page \(i + 1)" as NSString
                text.draw(at: CGPoint(x: 50, y: 150), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 24),
                    .foregroundColor: UIColor.black
                ])
            }
            if let page = PDFPage(image: image) {
                doc.insert(page, at: i)
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).pdf")
        doc.write(to: url)
        return url
    }

    func testMergePDFs() async throws {
        let pdf1 = try createTestPDF(pageCount: 2)
        let pdf2 = try createTestPDF(pageCount: 3)
        let outputName = "merged_test_\(UUID().uuidString)"

        let result = try await service.mergePDFs(from: [pdf1, pdf2], outputName: outputName)
        let mergedDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(mergedDoc)
        XCTAssertEqual(mergedDoc!.pageCount, 5)

        // Clean up
        try? FileManager.default.removeItem(at: pdf1)
        try? FileManager.default.removeItem(at: pdf2)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testSplitPDF() async throws {
        let pdf = try createTestPDF(pageCount: 5)
        let outputName = "split_test_\(UUID().uuidString)"

        let result = try await service.splitPDF(from: pdf, startPage: 2, endPage: 4, outputName: outputName)
        let splitDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(splitDoc)
        XCTAssertEqual(splitDoc!.pageCount, 3)

        // Clean up
        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testSplitPDF_invalidRange() async throws {
        let pdf = try createTestPDF(pageCount: 3)

        do {
            _ = try await service.splitPDF(from: pdf, startPage: 5, endPage: 2, outputName: "bad_split")
            XCTFail("Expected PDFToolsError to be thrown")
        } catch {
            XCTAssertTrue(error is PDFToolsError)
        }

        try? FileManager.default.removeItem(at: pdf)
    }

    func testCompressPDF() async throws {
        let pdf = try createTestPDF(pageCount: 2)
        let outputName = "compressed_test_\(UUID().uuidString)"

        let result = try await service.compressPDF(from: pdf, level: .high, outputName: outputName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))

        let compressedDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(compressedDoc)
        XCTAssertEqual(compressedDoc!.pageCount, 2)

        // Clean up
        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testCompressionLevel_quality() {
        XCTAssertEqual(PDFToolsService.CompressionLevel.low.quality, 0.8)
        XCTAssertEqual(PDFToolsService.CompressionLevel.medium.quality, 0.5)
        XCTAssertEqual(PDFToolsService.CompressionLevel.high.quality, 0.25)
    }

    func testLockAndUnlockPDF() async throws {
        let pdf = try createTestPDF(pageCount: 1)
        let password = "test123"
        let lockName = "locked_test_\(UUID().uuidString)"
        let unlockName = "unlocked_test_\(UUID().uuidString)"

        // Lock
        let locked = try await service.lockPDF(from: pdf, password: password, outputName: lockName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locked.url.path))

        let lockedDoc = PDFDocument(url: locked.url)
        XCTAssertNotNil(lockedDoc)
        XCTAssertTrue(lockedDoc!.isLocked)

        // Unlock
        let unlocked = try await service.unlockPDF(from: locked.url, password: password, outputName: unlockName)
        let unlockedDoc = PDFDocument(url: unlocked.url)
        XCTAssertNotNil(unlockedDoc)
        XCTAssertFalse(unlockedDoc!.isLocked)

        // Clean up
        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: locked.url)
        try? FileManager.default.removeItem(at: unlocked.url)
    }

    func testUnlockPDF_wrongPassword() async throws {
        let pdf = try createTestPDF(pageCount: 1)
        let lockName = "locked_wrong_\(UUID().uuidString)"

        let locked = try await service.lockPDF(from: pdf, password: "correct", outputName: lockName)

        do {
            _ = try await service.unlockPDF(from: locked.url, password: "wrong", outputName: "nope")
            XCTFail("Expected PDFToolsError to be thrown")
        } catch {
            XCTAssertTrue(error is PDFToolsError)
        }

        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: locked.url)
    }

    func testExtractPages() async throws {
        let pdf = try createTestPDF(pageCount: 5)
        let outputName = "extracted_test_\(UUID().uuidString)"

        let result = try await service.extractPages(from: pdf, pageIndices: [1, 3, 5], outputName: outputName)
        let extractedDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(extractedDoc)
        XCTAssertEqual(extractedDoc!.pageCount, 3)

        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testRotatePDF() async throws {
        let pdf = try createTestPDF(pageCount: 2)
        let outputName = "rotated_test_\(UUID().uuidString)"

        let result = try await service.rotatePDF(from: pdf, degrees: 90, outputName: outputName)
        let rotatedDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(rotatedDoc)
        XCTAssertEqual(rotatedDoc!.pageCount, 2)

        // Verify rotation was applied
        XCTAssertEqual(rotatedDoc!.page(at: 0)!.rotation, 90)

        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testReorderPDF() async throws {
        let pdf = try createTestPDF(pageCount: 3)
        let outputName = "reordered_test_\(UUID().uuidString)"

        let result = try await service.reorderPDF(from: pdf, newOrder: [3, 1, 2], outputName: outputName)
        let reorderedDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(reorderedDoc)
        XCTAssertEqual(reorderedDoc!.pageCount, 3)

        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testAddPageNumbers() async throws {
        let pdf = try createTestPDF(pageCount: 3)
        let outputName = "numbered_test_\(UUID().uuidString)"

        let result = try await service.addPageNumbers(from: pdf, outputName: outputName)
        let numberedDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(numberedDoc)
        XCTAssertEqual(numberedDoc!.pageCount, 3)

        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testAddWatermark() async throws {
        let pdf = try createTestPDF(pageCount: 2)
        let outputName = "watermarked_test_\(UUID().uuidString)"

        let result = try await service.addWatermark(from: pdf, text: "CONFIDENTIAL", outputName: outputName)
        let watermarkedDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(watermarkedDoc)
        XCTAssertEqual(watermarkedDoc!.pageCount, 2)

        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testCannotOpenPDF() async {
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent.pdf")
        do {
            _ = try await service.splitPDF(from: fakeURL, startPage: 1, endPage: 1, outputName: "x")
            XCTFail("Expected PDFToolsError to be thrown")
        } catch {
            XCTAssertTrue(error is PDFToolsError)
        }
    }

    func testCropPDF() async throws {
        let pdf = try createTestPDF(pageCount: 2)
        let outputName = "cropped_test_\(UUID().uuidString)"

        let result = try await service.cropPDF(from: pdf, top: 10, bottom: 10, left: 5, right: 5, outputName: outputName)
        let croppedDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(croppedDoc)
        XCTAssertEqual(croppedDoc!.pageCount, 2)

        // Verify crop was applied — cropBox should be smaller than original
        let page = croppedDoc!.page(at: 0)!
        let cropBox = page.bounds(for: .cropBox)
        XCTAssertLessThan(cropBox.width, 200)
        XCTAssertLessThan(cropBox.height, 300)

        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testSignPDF() async throws {
        let pdf = try createTestPDF(pageCount: 1)
        let outputName = "signed_test_\(UUID().uuidString)"

        // Create a small test signature image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50))
        let sigImage = renderer.image { ctx in
            UIColor.black.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 10, y: 25))
            path.addLine(to: CGPoint(x: 90, y: 25))
            path.stroke()
        }

        let result = try await service.signPDF(
            from: pdf,
            signatureImage: sigImage,
            pageIndex: 0,
            position: CGPoint(x: 0.8, y: 0.9),
            signatureSize: CGSize(width: 150, height: 75),
            outputName: outputName
        )
        let signedDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(signedDoc)
        XCTAssertEqual(signedDoc!.pageCount, 1)

        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testReadMetadata() throws {
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 300))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
        }
        if let page = PDFPage(image: image) { doc.insert(page, at: 0) }

        doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] = "Test Title"
        doc.documentAttributes?[PDFDocumentAttribute.authorAttribute] = "Test Author"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("meta_test_\(UUID().uuidString).pdf")
        doc.write(to: url)

        let metadata = try service.readMetadata(from: url)
        XCTAssertEqual(metadata.title, "Test Title")
        XCTAssertEqual(metadata.author, "Test Author")

        try? FileManager.default.removeItem(at: url)
    }

    func testWriteMetadata() async throws {
        let pdf = try createTestPDF(pageCount: 1)
        let outputName = "metadata_test_\(UUID().uuidString)"

        let metadata = PDFMetadata(title: "New Title", author: "New Author", subject: "New Subject", keywords: "test, pdf")
        let result = try await service.writeMetadata(to: pdf, metadata: metadata, outputName: outputName)

        let updatedDoc = PDFDocument(url: result.url)
        XCTAssertNotNil(updatedDoc)
        let attrs = updatedDoc!.documentAttributes
        XCTAssertEqual(attrs?[PDFDocumentAttribute.titleAttribute] as? String, "New Title")
        XCTAssertEqual(attrs?[PDFDocumentAttribute.authorAttribute] as? String, "New Author")

        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }
}

@MainActor
final class ConverterServiceTests: XCTestCase {
    let service = ConverterService.shared

    func testPdfToText() throws {
        // Create a PDF with text
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            let text = "Hello World test content" as NSString
            text.draw(at: CGPoint(x: 50, y: 50), withAttributes: [
                .font: UIFont.systemFont(ofSize: 24)
            ])
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("text_test_\(UUID().uuidString).pdf")
        try data.write(to: url)

        let extractedText = try service.pdfToText(url: url)
        XCTAssertFalse(extractedText.isEmpty)

        try? FileManager.default.removeItem(at: url)
    }

    func testSaveTextFile() throws {
        let outputName = "text_output_\(UUID().uuidString)"
        let result = try service.saveTextFile(text: "Sample text content", outputName: outputName)

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        XCTAssertTrue(result.relativePath.hasSuffix(".txt"))

        let content = try String(contentsOf: result.url, encoding: .utf8)
        XCTAssertEqual(content, "Sample text content")

        try? FileManager.default.removeItem(at: result.url)
    }

    func testSaveTextFile_emptyName() {
        XCTAssertThrowsError(try service.saveTextFile(text: "content", outputName: "  "))
    }

    func testImageFormat() {
        XCTAssertEqual(ConverterService.ImageFormat.allCases.count, 2)
        XCTAssertEqual(ConverterService.ImageFormat.jpg.rawValue, "JPG")
        XCTAssertEqual(ConverterService.ImageFormat.png.rawValue, "PNG")
    }

    func testCannotOpenFile() {
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("nope.pdf")
        XCTAssertThrowsError(try service.pdfToText(url: fakeURL))
    }
}

// MARK: - ViewModel Tests

@MainActor
final class FilesViewModelTests: XCTestCase {
    var viewModel: FilesViewModel!

    override func setUp() {
        super.setUp()
        viewModel = FilesViewModel()
    }

    func testDefaultState() {
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.selectedCategory, .all)
        XCTAssertEqual(viewModel.sortOption, .dateDesc)
    }

    func testFilteredAndSorted_byCategory() {
        let pdfFile = DocumentFile(name: "Doc", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        let imgFile = DocumentFile(name: "Photo", fileExtension: "jpg", relativeFilePath: "", fileSize: 200)

        viewModel.selectedCategory = .pdf
        let filtered = viewModel.filteredAndSorted([pdfFile, imgFile])

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "Doc")
    }

    func testFilteredAndSorted_bySearch() {
        let file1 = DocumentFile(name: "Invoice", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        let file2 = DocumentFile(name: "Photo", fileExtension: "jpg", relativeFilePath: "", fileSize: 200)

        viewModel.searchText = "inv"
        let filtered = viewModel.filteredAndSorted([file1, file2])

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "Invoice")
    }

    func testFilteredAndSorted_sortByName() {
        let fileA = DocumentFile(name: "Alpha", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        let fileZ = DocumentFile(name: "Zeta", fileExtension: "pdf", relativeFilePath: "", fileSize: 200)

        viewModel.sortOption = .nameAsc
        let sorted = viewModel.filteredAndSorted([fileZ, fileA])

        XCTAssertEqual(sorted.first?.name, "Alpha")
        XCTAssertEqual(sorted.last?.name, "Zeta")
    }

    func testFilteredAndSorted_sortByNameDesc() {
        let fileA = DocumentFile(name: "Alpha", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        let fileZ = DocumentFile(name: "Zeta", fileExtension: "pdf", relativeFilePath: "", fileSize: 200)

        viewModel.sortOption = .nameDesc
        let sorted = viewModel.filteredAndSorted([fileA, fileZ])

        XCTAssertEqual(sorted.first?.name, "Zeta")
    }

    func testFilteredAndSorted_sortBySize() {
        let small = DocumentFile(name: "Small", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        let large = DocumentFile(name: "Large", fileExtension: "pdf", relativeFilePath: "", fileSize: 9000)

        viewModel.sortOption = .sizeDesc
        let sorted = viewModel.filteredAndSorted([small, large])

        XCTAssertEqual(sorted.first?.name, "Large")
    }

    func testFilteredAndSorted_sortByType() {
        let jpg = DocumentFile(name: "Photo", fileExtension: "jpg", relativeFilePath: "", fileSize: 100)
        let pdf = DocumentFile(name: "Doc", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)

        viewModel.sortOption = .typeAsc
        let sorted = viewModel.filteredAndSorted([pdf, jpg])

        XCTAssertEqual(sorted.first?.fileExtension, "jpg")
    }

    func testCategoryCount() {
        let files = [
            DocumentFile(name: "A", fileExtension: "pdf", relativeFilePath: "", fileSize: 100),
            DocumentFile(name: "B", fileExtension: "pdf", relativeFilePath: "", fileSize: 100),
            DocumentFile(name: "C", fileExtension: "jpg", relativeFilePath: "", fileSize: 100),
        ]

        XCTAssertEqual(viewModel.categoryCount(.all, in: files), 3)
        XCTAssertEqual(viewModel.categoryCount(.pdf, in: files), 2)
        XCTAssertEqual(viewModel.categoryCount(.img, in: files), 1)
        XCTAssertEqual(viewModel.categoryCount(.doc, in: files), 0)
    }

    func testRecentFiles() {
        let now = Date.now
        let file1 = DocumentFile(name: "Old", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        file1.lastOpenedAt = Calendar.current.date(byAdding: .hour, value: -2, to: now)

        let file2 = DocumentFile(name: "New", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        file2.lastOpenedAt = now

        let file3 = DocumentFile(name: "Never", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        // lastOpenedAt is nil

        let recent = viewModel.recentFiles([file1, file2, file3], limit: 5)
        XCTAssertEqual(recent.count, 2) // file3 excluded (nil lastOpenedAt)
        XCTAssertEqual(recent.first?.name, "New") // Most recent first
    }
}

@MainActor
final class ScanReviewViewModelTests: XCTestCase {
    var viewModel: ScanReviewViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ScanReviewViewModel()
    }

    func testDefaultState() {
        XCTAssertTrue(viewModel.pages.isEmpty)
        XCTAssertEqual(viewModel.selectedPageIndex, 0)
        XCTAssertEqual(viewModel.selectedFilter, .color)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertFalse(viewModel.didSave)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadScannedImages() {
        let images = [
            UIImage(systemName: "doc")!,
            UIImage(systemName: "photo")!,
        ]
        viewModel.loadScannedImages(images)

        XCTAssertEqual(viewModel.pages.count, 2)
        XCTAssertFalse(viewModel.fileName.isEmpty)
    }

    func testCurrentPage() {
        XCTAssertNil(viewModel.currentPage) // No pages loaded

        viewModel.loadScannedImages([UIImage(systemName: "doc")!])
        XCTAssertNotNil(viewModel.currentPage)
    }

    func testPageCountText() {
        viewModel.loadScannedImages([
            UIImage(systemName: "doc")!,
            UIImage(systemName: "photo")!,
            UIImage(systemName: "star")!,
        ])
        XCTAssertEqual(viewModel.pageCountText, "1 / 3")

        viewModel.selectPage(at: 2)
        XCTAssertEqual(viewModel.pageCountText, "3 / 3")
    }

    func testSelectPage() {
        viewModel.loadScannedImages([
            UIImage(systemName: "doc")!,
            UIImage(systemName: "photo")!,
        ])

        viewModel.selectPage(at: 1)
        XCTAssertEqual(viewModel.selectedPageIndex, 1)

        // Out of bounds - no change
        viewModel.selectPage(at: 5)
        XCTAssertEqual(viewModel.selectedPageIndex, 1)
    }

    func testDeletePage() {
        viewModel.loadScannedImages([
            UIImage(systemName: "doc")!,
            UIImage(systemName: "photo")!,
            UIImage(systemName: "star")!,
        ])

        viewModel.deletePage(at: 1)
        XCTAssertEqual(viewModel.pages.count, 2)
    }

    func testDeletePage_cannotDeleteLastPage() {
        viewModel.loadScannedImages([UIImage(systemName: "doc")!])
        viewModel.deletePage(at: 0)
        XCTAssertEqual(viewModel.pages.count, 1) // Cannot delete last page
    }

    func testDeletePage_adjustsSelectedIndex() {
        viewModel.loadScannedImages([
            UIImage(systemName: "doc")!,
            UIImage(systemName: "photo")!,
        ])
        viewModel.selectPage(at: 1)
        viewModel.deletePage(at: 1)

        XCTAssertEqual(viewModel.pages.count, 1)
        XCTAssertEqual(viewModel.selectedPageIndex, 0) // Adjusted
    }

    func testApplyFilter() {
        let image = createTestImage()
        viewModel.loadScannedImages([image])

        viewModel.applyFilter(.grayscale)
        XCTAssertEqual(viewModel.pages[0].appliedFilter, .grayscale)
        XCTAssertEqual(viewModel.selectedFilter, .grayscale)
    }

    func testRotateCurrentPage() {
        let image = createTestImage()
        viewModel.loadScannedImages([image])

        viewModel.rotateCurrentPage()
        XCTAssertEqual(viewModel.pages[0].rotation, 90)

        viewModel.rotateCurrentPage()
        XCTAssertEqual(viewModel.pages[0].rotation, 180)
    }

    func testMovePage() {
        viewModel.loadScannedImages([
            UIImage(systemName: "doc")!,
            UIImage(systemName: "photo")!,
            UIImage(systemName: "star")!,
        ])

        let originalFirstId = viewModel.pages[0].id
        viewModel.movePage(from: IndexSet(integer: 2), to: 0)
        XCTAssertNotEqual(viewModel.pages[0].id, originalFirstId)
    }

    private func createTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50))
        return renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        }
    }
}

@MainActor
final class ChatViewModelTests: XCTestCase {
    var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ChatViewModel()
    }

    func testDefaultState() {
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertFalse(viewModel.isTyping)
        XCTAssertNil(viewModel.currentConversation)
    }

    func testQuickActions() {
        XCTAssertFalse(viewModel.actions.isEmpty)
        XCTAssertEqual(viewModel.actions.count, 6)

        let labels = viewModel.actions.map { $0.label }
        XCTAssertTrue(labels.contains("Scan"))
        XCTAssertTrue(labels.contains("Merge"))
        XCTAssertTrue(labels.contains("Convert"))
        XCTAssertTrue(labels.contains("OCR"))
        XCTAssertTrue(labels.contains("Compress"))
        XCTAssertTrue(labels.contains("Watermark"))
    }

    func testMessagesForCurrentConversation_noConversation() {
        let conv = Conversation()
        let messages = [
            ChatMessage(content: "Hi", role: "user", conversation: conv)
        ]
        let result = viewModel.messagesForCurrentConversation(allMessages: messages)
        XCTAssertTrue(result.isEmpty)
    }
}

@MainActor
final class PDFToolsViewModelTests: XCTestCase {
    var viewModel: PDFToolsViewModel!

    override func setUp() {
        super.setUp()
        viewModel = PDFToolsViewModel()
    }

    func testDefaultState() {
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(viewModel.didComplete)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.resultFileName)
    }

    func testReset() {
        viewModel.isProcessing = true
        viewModel.didComplete = true
        viewModel.errorMessage = "Some error"
        viewModel.showError = true
        viewModel.resultFileName = "file.pdf"

        viewModel.reset()

        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(viewModel.didComplete)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.resultFileName)
    }
}

@MainActor
final class ConverterViewModelTests: XCTestCase {
    var viewModel: ConverterViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ConverterViewModel()
    }

    func testDefaultState() {
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(viewModel.didComplete)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.resultFileName)
        XCTAssertNil(viewModel.extractedText)
    }

    func testReset() {
        viewModel.isProcessing = true
        viewModel.didComplete = true
        viewModel.errorMessage = "Error"
        viewModel.showError = true
        viewModel.resultFileName = "test.pdf"
        viewModel.extractedText = "Some text"

        viewModel.reset()

        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(viewModel.didComplete)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.resultFileName)
        XCTAssertNil(viewModel.extractedText)
    }
}

@MainActor
final class AIDocumentViewModelTests: XCTestCase {
    var viewModel: AIDocumentViewModel!

    override func setUp() {
        super.setUp()
        viewModel = AIDocumentViewModel()
    }

    func testDefaultState() {
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(viewModel.didComplete)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.resultText)
        XCTAssertNil(viewModel.resultFileName)
        XCTAssertNil(viewModel.extractedDocumentText)
        XCTAssertTrue(viewModel.chatMessages.isEmpty)
    }

    func testReset() {
        viewModel.isProcessing = true
        viewModel.didComplete = true
        viewModel.errorMessage = "Error"
        viewModel.showError = true
        viewModel.resultText = "Some result"
        viewModel.resultFileName = "file.txt"
        viewModel.extractedDocumentText = "Some text"
        viewModel.chatMessages = [(role: "user", content: "hi")]

        viewModel.reset()

        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(viewModel.didComplete)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.resultText)
        XCTAssertNil(viewModel.resultFileName)
        XCTAssertNil(viewModel.extractedDocumentText)
        XCTAssertTrue(viewModel.chatMessages.isEmpty)
    }

    func testAskQuestionWithoutDocument() {
        // askQuestion should do nothing when no document is loaded
        viewModel.askQuestion("What is this?")
        XCTAssertTrue(viewModel.chatMessages.isEmpty)
        XCTAssertFalse(viewModel.isProcessing)
    }
}

// MARK: - Error Type Tests

final class ErrorTypeTests: XCTestCase {

    func testFileStorageError_descriptions() {
        XCTAssertNotNil(FileStorageError.nameAlreadyExists.errorDescription)
        XCTAssertNotNil(FileStorageError.fileNotFound.errorDescription)
    }

    func testScannerError_descriptions() {
        XCTAssertNotNil(ScannerError.pdfGenerationFailed.errorDescription)
        XCTAssertNotNil(ScannerError.saveFailed.errorDescription)
    }

    func testPDFToolsError_descriptions() {
        XCTAssertNotNil(PDFToolsError.cannotOpenPDF.errorDescription)
        XCTAssertNotNil(PDFToolsError.noValidPages.errorDescription)
        XCTAssertNotNil(PDFToolsError.invalidPageRange.errorDescription)
        XCTAssertNotNil(PDFToolsError.incorrectPassword.errorDescription)
        XCTAssertNotNil(PDFToolsError.saveFailed.errorDescription)
    }

    func testOCRError_descriptions() {
        XCTAssertNotNil(OCRError.cannotLoadImage.errorDescription)
        XCTAssertNotNil(OCRError.cannotOpenPDF.errorDescription)
        XCTAssertNotNil(OCRError.noTextFound.errorDescription)
    }

    func testConverterError_descriptions() {
        XCTAssertNotNil(ConverterError.noValidInput.errorDescription)
        XCTAssertNotNil(ConverterError.cannotOpenFile.errorDescription)
        XCTAssertNotNil(ConverterError.conversionFailed.errorDescription)
        XCTAssertNotNil(ConverterError.noTextContent.errorDescription)
    }
}

// MARK: - QuickAction Tests

final class QuickActionTests: XCTestCase {

    func testInit() {
        let action = QuickAction(label: "Scan", icon: "doc.viewfinder", prompt: "Scan a doc")
        XCTAssertNotNil(action.id)
        XCTAssertEqual(action.label, "Scan")
        XCTAssertEqual(action.icon, "doc.viewfinder")
        XCTAssertEqual(action.prompt, "Scan a doc")
    }
}

// MARK: - AI Provider Tests

@MainActor
final class KeywordMatchingProviderTests: XCTestCase {
    let provider = KeywordMatchingProvider()

    func testScanKeyword() async throws {
        let response = try await provider.generateResponse(for: "I want to scan a document", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Scanner")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Scanner" })
        XCTAssertFalse(response.text.isEmpty)
    }

    func testMergeKeyword() async throws {
        let response = try await provider.generateResponse(for: "merge my PDFs", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Merge PDF")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Merge PDF" })
    }

    func testConvertKeyword() async throws {
        let response = try await provider.generateResponse(for: "convert a file", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Converter")
        XCTAssertEqual(response.actions.count, 4)
    }

    func testCompressKeyword() async throws {
        let response = try await provider.generateResponse(for: "compress PDF", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Compress")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Compress" })
    }

    func testLockKeyword() async throws {
        let response = try await provider.generateResponse(for: "password protect my file", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Lock/Unlock")
        XCTAssertEqual(response.actions.count, 2)
    }

    func testGreetingKeyword() async throws {
        let response = try await provider.generateResponse(for: "hello", conversationHistory: [])
        XCTAssertNil(response.toolBadge)
        XCTAssertTrue(response.text.contains("DocSage"))
        XCTAssertTrue(response.actions.contains { $0.actionType == .navigateTab })
    }

    func testDefaultResponse() async throws {
        let response = try await provider.generateResponse(for: "some random input xyz", conversationHistory: [])
        XCTAssertNil(response.toolBadge)
        XCTAssertFalse(response.text.isEmpty)
        XCTAssertTrue(response.actions.contains { $0.toolId == "Scanner" })
    }

    func testSignKeyword() async throws {
        let response = try await provider.generateResponse(for: "I need to sign a document", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Sign PDF")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Sign PDF" })
    }

    func testCropKeyword() async throws {
        let response = try await provider.generateResponse(for: "crop the margins", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Crop PDF")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Crop PDF" })
    }

    func testMetadataKeyword() async throws {
        let response = try await provider.generateResponse(for: "edit metadata", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "PDF Metadata")
        XCTAssertTrue(response.actions.contains { $0.toolId == "PDF Metadata" })
    }

    func testSummarizeKeyword() async throws {
        let response = try await provider.generateResponse(for: "summarize this PDF", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Summarize PDF")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Summarize PDF" })
    }

    func testAskKeyword() async throws {
        let response = try await provider.generateResponse(for: "ask a question about the PDF", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Ask PDF")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Ask PDF" })
    }

    func testTranslateKeyword() async throws {
        let response = try await provider.generateResponse(for: "translate to Spanish", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Translate PDF")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Translate PDF" })
    }

    func testEmailKeyword() async throws {
        let response = try await provider.generateResponse(for: "email this file", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Email PDF")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Email PDF" })
    }

    func testSupportsStreaming() {
        XCTAssertFalse(provider.supportsStreaming)
    }

    func testStreamFallsBackToGenerate() async throws {
        let response = try await provider.streamResponse(
            for: "scan",
            conversationHistory: [],
            onPartialUpdate: { _ in }
        )
        XCTAssertEqual(response.toolBadge, "Scanner")
    }
}

@MainActor
final class AIServiceTests: XCTestCase {
    func testBackendSelection() {
        let service = AIService.shared
        // On simulator, Foundation Models is unavailable — should fallback
        #if targetEnvironment(simulator)
        XCTAssertEqual(service.activeBackend, .keywordMatching)
        XCTAssertFalse(service.isOnDeviceAIAvailable)
        #endif
    }

    func testSupportsStreaming() {
        let service = AIService.shared
        #if targetEnvironment(simulator)
        XCTAssertFalse(service.supportsStreaming)
        #endif
    }

    func testGenerateResponse() async throws {
        let service = AIService.shared
        let response = try await service.generateResponse(for: "scan", conversationHistory: [])
        XCTAssertFalse(response.text.isEmpty)
        XCTAssertEqual(response.toolBadge, "Scanner")
    }
}

final class AIResponseTests: XCTestCase {
    func testAIResponseConstruction() {
        let actions = [
            ChatAction(label: "Open Scanner", icon: "doc.viewfinder", actionType: .openTool, toolId: "Scanner")
        ]
        let response = AIResponse(text: "Let me help", toolBadge: "Scanner", actions: actions)
        XCTAssertEqual(response.text, "Let me help")
        XCTAssertEqual(response.toolBadge, "Scanner")
        XCTAssertEqual(response.actions.count, 1)
        XCTAssertEqual(response.actions.first?.toolId, "Scanner")
    }

    func testAIResponseWithNoActions() {
        let response = AIResponse(text: "Hello!", toolBadge: nil, actions: [])
        XCTAssertNil(response.toolBadge)
        XCTAssertTrue(response.actions.isEmpty)
    }
}

// MARK: - App Icon Generator Tests

final class AppIconGeneratorTests: XCTestCase {
    func testGenerateIcon_produces1024x1024Image() {
        let icon = AppIconGenerator.generateIcon(size: 1024)
        XCTAssertEqual(icon.size.width, 1024)
        XCTAssertEqual(icon.size.height, 1024)
    }

    func testGenerateIcon_producesValidPNGData() {
        let icon = AppIconGenerator.generateIcon(size: 1024)
        let pngData = icon.pngData()
        XCTAssertNotNil(pngData)
        XCTAssertGreaterThan(pngData!.count, 1000)
    }

    func testGenerateIcon_customSize() {
        let icon = AppIconGenerator.generateIcon(size: 512)
        XCTAssertEqual(icon.size.width, 512)
        XCTAssertEqual(icon.size.height, 512)
    }
}

// MARK: - App Icon Export (generates the actual PNG to temp directory)

final class AppIconExportTests: XCTestCase {
    func testExportIconToPNG() throws {
        let icon = AppIconGenerator.generateIcon(size: 1024)
        let data = try XCTUnwrap(icon.pngData())

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppIcon-1024.png")
        try data.write(to: tempPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempPath.path))

        // Clean up
        try? FileManager.default.removeItem(at: tempPath)
    }
}
