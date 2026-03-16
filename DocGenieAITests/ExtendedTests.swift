import XCTest
import UIKit
import PDFKit
import SwiftUI
import SwiftData
import TipKit
@testable import DocGenieAI

// MARK: - Navigation Tests

@MainActor
final class NavigationRouterTests: XCTestCase {
    var router: NavigationRouter!

    override func setUp() {
        super.setUp()
        router = NavigationRouter()
    }

    func testDefaultTab() {
        XCTAssertEqual(router.selectedTab, .chat)
    }

    func testNavigateToTools() {
        router.selectedTab = .chat
        router.navigateToTools()
        XCTAssertEqual(router.selectedTab, .tools)
    }

    func testOpenToolFromAnywhere() {
        router.selectedTab = .chat
        router.openToolFromAnywhere(.mergePDF)
        XCTAssertEqual(router.selectedTab, .tools)
        XCTAssertEqual(router.toolToOpen, .mergePDF)
    }

    func testResetCurrentTab_settings() {
        router.selectedTab = .settings
        router.resetCurrentTab()
        XCTAssertEqual(router.selectedTab, .settings)
    }

    func testResetCurrentTab_chat() {
        router.selectedTab = .chat
        router.chatPath.append("test")
        router.resetCurrentTab()
        XCTAssertTrue(router.chatPath.isEmpty)
    }

    func testResetCurrentTab_tools() {
        router.selectedTab = .tools
        router.toolsPath.append("test")
        router.resetCurrentTab()
        XCTAssertTrue(router.toolsPath.isEmpty)
    }

    func testToolToOpen_initiallyNil() {
        XCTAssertNil(router.toolToOpen)
    }
}

final class AppTabTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(AppTab.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(AppTab.chat.rawValue, "chat")
        XCTAssertEqual(AppTab.tools.rawValue, "tools")
        XCTAssertEqual(AppTab.settings.rawValue, "settings")
    }

    func testIdentifiable() {
        XCTAssertEqual(AppTab.chat.id, "chat")
        XCTAssertEqual(AppTab.tools.id, "tools")
    }

    func testTitles() {
        XCTAssertEqual(AppTab.chat.title, "Chat")
        XCTAssertEqual(AppTab.tools.title, "Tools")
        XCTAssertEqual(AppTab.settings.title, "Settings")
    }

    func testSystemImages() {
        XCTAssertEqual(AppTab.chat.systemImage, "bubble.left.and.bubble.right")
        XCTAssertEqual(AppTab.tools.systemImage, "wrench.and.screwdriver")
        XCTAssertEqual(AppTab.settings.systemImage, "gearshape")
    }
}

// MARK: - ChatToolCoordinator Tests

@MainActor
final class ChatToolCoordinatorTests: XCTestCase {
    var coordinator: ChatToolCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = ChatToolCoordinator()
    }

    func testDefaultState() {
        XCTAssertNil(coordinator.activeTool)
        XCTAssertFalse(coordinator.showScanner)
    }

    func testOpenTool_scanner() {
        coordinator.openTool(.scanner)
        XCTAssertTrue(coordinator.showScanner)
        XCTAssertNil(coordinator.activeTool)
    }

    func testOpenTool_nonScanner() {
        coordinator.openTool(.mergePDF)
        XCTAssertEqual(coordinator.activeTool, .mergePDF)
        XCTAssertFalse(coordinator.showScanner)
    }

    func testOpenTool_multipleNonScanner() {
        coordinator.openTool(.splitPDF)
        XCTAssertEqual(coordinator.activeTool, .splitPDF)

        coordinator.openTool(.compressPDF)
        XCTAssertEqual(coordinator.activeTool, .compressPDF)
    }

    func testDismissTool() {
        coordinator.activeTool = .lockPDF
        coordinator.dismissTool()
        XCTAssertNil(coordinator.activeTool)
    }

    func testToolForId_byRawValue() {
        let tool = coordinator.toolForId("Merge PDF")
        XCTAssertEqual(tool, .mergePDF)
    }

    func testToolForId_byId() {
        let tool = coordinator.toolForId("Scanner")
        XCTAssertEqual(tool, .scanner)
    }

    func testToolForId_notFound() {
        let tool = coordinator.toolForId("Nonexistent Tool")
        XCTAssertNil(tool)
    }

    func testToolForId_allTools() {
        for tool in ToolItem.allCases {
            let found = coordinator.toolForId(tool.rawValue)
            XCTAssertEqual(found, tool, "Failed to find tool: \(tool.rawValue)")
        }
    }
}

// MARK: - DocumentViewerViewModel Tests

@MainActor
final class DocumentViewerViewModelExtendedTests: XCTestCase {
    var viewModel: DocumentViewerViewModel!

    override func setUp() {
        super.setUp()
        viewModel = DocumentViewerViewModel()
    }

    func testDefaultState() {
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadFile_missingFile() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, configurations: config)
        let context = ModelContext(container)

        let file = DocumentFile(
            name: "Missing",
            fileExtension: "pdf",
            relativeFilePath: "DocGenieFiles/totally_missing_xyz_123.pdf",
            fileSize: 0
        )

        viewModel.loadFile(file, context: context)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("not found"))
    }

    func testLoadFile_existingFile() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, configurations: config)
        let context = ModelContext(container)

        // Create a real file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("viewer_test_\(UUID().uuidString).txt")
        try "Content".write(to: tempFile, atomically: true, encoding: .utf8)

        let result = try FileStorageService.shared.importFile(from: tempFile)
        let file = DocumentFile(
            name: "Test",
            fileExtension: "txt",
            relativeFilePath: result.relativePath,
            fileSize: 100
        )

        viewModel.loadFile(file, context: context)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(file.lastOpenedAt)

        // Clean up
        try? FileStorageService.shared.deleteFile(at: result.relativePath)
        try? FileManager.default.removeItem(at: tempFile)
    }
}

// MARK: - ChatAction Tests

final class ChatActionExtendedTests: XCTestCase {

    func testChatActionType_rawValues() {
        XCTAssertEqual(ChatActionType.openTool.rawValue, "openTool")
        XCTAssertEqual(ChatActionType.navigateTab.rawValue, "navigateTab")
        XCTAssertEqual(ChatActionType.openFile.rawValue, "openFile")
        XCTAssertEqual(ChatActionType.showResult.rawValue, "showResult")
    }

    func testChatAction_encodeDecode() throws {
        let action = ChatAction(
            label: "Open Scanner",
            icon: "doc.viewfinder",
            actionType: .openTool,
            toolId: "Scanner"
        )

        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(ChatAction.self, from: data)

        XCTAssertEqual(decoded.label, "Open Scanner")
        XCTAssertEqual(decoded.icon, "doc.viewfinder")
        XCTAssertEqual(decoded.actionType, .openTool)
        XCTAssertEqual(decoded.toolId, "Scanner")
        XCTAssertNil(decoded.tabId)
        XCTAssertNil(decoded.fileId)
    }

    func testChatAction_withTabId() throws {
        let action = ChatAction(
            label: "Go to Settings",
            icon: "gearshape",
            actionType: .navigateTab,
            tabId: "settings"
        )

        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(ChatAction.self, from: data)

        XCTAssertEqual(decoded.actionType, .navigateTab)
        XCTAssertEqual(decoded.tabId, "settings")
        XCTAssertNil(decoded.toolId)
    }

    func testChatAction_arrayEncodeDecode() throws {
        let actions = [
            ChatAction(label: "A", icon: "a", actionType: .openTool, toolId: "Scanner"),
            ChatAction(label: "B", icon: "b", actionType: .navigateTab, tabId: "tools"),
        ]

        let data = try JSONEncoder().encode(actions)
        let decoded = try JSONDecoder().decode([ChatAction].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].toolId, "Scanner")
        XCTAssertEqual(decoded[1].tabId, "tools")
    }
}

// MARK: - ChatMessage Actions Parsing Tests

final class ChatMessageActionsTests: XCTestCase {

    func testActions_withValidJSON() {
        let conv = Conversation()
        let actions = [
            ChatAction(label: "Test", icon: "star", actionType: .openTool, toolId: "Scanner")
        ]
        let msg = ChatMessage(content: "Hi", role: "assistant", conversation: conv, actions: actions)

        XCTAssertNotNil(msg.actionsJSON)
        let parsedActions = msg.actions
        XCTAssertEqual(parsedActions.count, 1)
        XCTAssertEqual(parsedActions.first?.toolId, "Scanner")
    }

    func testActions_withInvalidJSON() {
        let conv = Conversation()
        let msg = ChatMessage(content: "Hi", role: "assistant", conversation: conv)
        msg.actionsJSON = "invalid json"

        XCTAssertTrue(msg.actions.isEmpty)
    }

    func testActions_withNilJSON() {
        let conv = Conversation()
        let msg = ChatMessage(content: "Hi", role: "user", conversation: conv)

        XCTAssertNil(msg.actionsJSON)
        XCTAssertTrue(msg.actions.isEmpty)
    }

    func testActions_caching() {
        let conv = Conversation()
        let actions = [
            ChatAction(label: "A", icon: "a", actionType: .openTool, toolId: "Merge PDF"),
            ChatAction(label: "B", icon: "b", actionType: .navigateTab, tabId: "settings"),
        ]
        let msg = ChatMessage(content: "Hi", role: "assistant", conversation: conv, actions: actions)

        // First access
        let first = msg.actions
        XCTAssertEqual(first.count, 2)

        // Second access (should use cache)
        let second = msg.actions
        XCTAssertEqual(second.count, 2)
    }

    func testChatMessage_initWithActions() {
        let conv = Conversation()
        let actions = [
            ChatAction(label: "Scan", icon: "doc.viewfinder", actionType: .openTool, toolId: "Scanner")
        ]
        let msg = ChatMessage(content: "Test", role: "assistant", conversation: conv, toolBadge: "Scanner", actions: actions)

        XCTAssertEqual(msg.toolBadge, "Scanner")
        XCTAssertNotNil(msg.actionsJSON)
        XCTAssertEqual(msg.actions.count, 1)
    }

    func testChatMessage_emptyActions() {
        let conv = Conversation()
        let msg = ChatMessage(content: "Test", role: "assistant", conversation: conv, actions: [])
        XCTAssertNil(msg.actionsJSON)
        XCTAssertTrue(msg.actions.isEmpty)
    }
}

// MARK: - WhatsNew Tests

final class WhatsNewDataTests: XCTestCase {

    func testFeatures_v1_1() {
        let features = WhatsNewData.features(for: "1.1")
        XCTAssertNotNil(features)
        XCTAssertEqual(features!.count, 4)
    }

    func testFeatures_v1_1_titles() {
        let features = WhatsNewData.features(for: "1.1")!
        let titles = features.map { $0.title }
        XCTAssertTrue(titles.contains("AI Tools Suite"))
        XCTAssertTrue(titles.contains("Sign Documents"))
        XCTAssertTrue(titles.contains("Crop & Metadata Tools"))
        XCTAssertTrue(titles.contains("Smart Tips"))
    }

    func testFeatures_v1_1_icons() {
        let features = WhatsNewData.features(for: "1.1")!
        XCTAssertEqual(features[0].icon, "brain")
        XCTAssertEqual(features[1].icon, "signature")
        XCTAssertEqual(features[2].icon, "crop")
        XCTAssertEqual(features[3].icon, "lightbulb")
    }

    func testFeatures_v1_1_descriptions() {
        let features = WhatsNewData.features(for: "1.1")!
        for feature in features {
            XCTAssertFalse(feature.description.isEmpty)
        }
    }

    func testFeatures_unknownVersion() {
        XCTAssertNil(WhatsNewData.features(for: "99.99"))
    }

    func testFeatures_emptyString() {
        XCTAssertNil(WhatsNewData.features(for: ""))
    }

    func testWhatsNewFeature_hasId() {
        let feature = WhatsNewFeature(icon: "star", iconColor: .blue, title: "Test", description: "Desc")
        XCTAssertNotNil(feature.id)
    }

    func testWhatsNewFeature_uniqueIds() {
        let f1 = WhatsNewFeature(icon: "a", iconColor: .red, title: "A", description: "")
        let f2 = WhatsNewFeature(icon: "b", iconColor: .blue, title: "B", description: "")
        XCTAssertNotEqual(f1.id, f2.id)
    }
}

// MARK: - HapticManager Tests

@MainActor
final class HapticManagerTests: XCTestCase {
    // These just verify the methods don't crash in test environment
    func testLight() { HapticManager.light() }
    func testMedium() { HapticManager.medium() }
    func testHeavy() { HapticManager.heavy() }
    func testSuccess() { HapticManager.success() }
    func testError() { HapticManager.error() }
    func testSelection() { HapticManager.selection() }
}

// MARK: - ThumbnailService Tests

@MainActor
final class ThumbnailServiceTests: XCTestCase {
    let service = ThumbnailService.shared

    func testThumbnail_invalidURL() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent.pdf")
        let thumb = service.thumbnail(for: url)
        XCTAssertNil(thumb)
    }

    func testThumbnail_validPDF() throws {
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        if let page = PDFPage(image: image) { doc.insert(page, at: 0) }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("thumb_test_\(UUID().uuidString).pdf")
        doc.write(to: url)

        let thumb = service.thumbnail(for: url)
        XCTAssertNotNil(thumb)
        XCTAssertGreaterThan(thumb!.size.width, 0)

        // Test caching - second call should return cached
        let thumb2 = service.thumbnail(for: url)
        XCTAssertNotNil(thumb2)

        try? FileManager.default.removeItem(at: url)
    }

    func testThumbnail_customSize() throws {
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 300))
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
        }
        if let page = PDFPage(image: image) { doc.insert(page, at: 0) }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("thumb_custom_\(UUID().uuidString).pdf")
        doc.write(to: url)

        let thumb = service.thumbnail(for: url, size: CGSize(width: 120, height: 120))
        XCTAssertNotNil(thumb)

        try? FileManager.default.removeItem(at: url)
    }

    func testClearCache() {
        // Should not crash
        service.clearCache()
    }
}

// MARK: - Extended ConverterService Tests

@MainActor
final class ConverterServiceExtendedTests: XCTestCase {
    let service = ConverterService.shared

    func testImagesToPDF() throws {
        // Create test images
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        let tempDir = FileManager.default.temporaryDirectory
        let imgPath = tempDir.appendingPathComponent("test_img_\(UUID().uuidString).jpg")
        try image.jpegData(compressionQuality: 0.9)?.write(to: imgPath)

        let result = try service.imagesToPDF(urls: [imgPath], outputName: "img_to_pdf_test_\(UUID().uuidString)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))

        let doc = PDFDocument(url: result.url)
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc!.pageCount, 1)

        try? FileManager.default.removeItem(at: imgPath)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testImagesToPDF_noValidImages() {
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("fake_\(UUID().uuidString).xyz")
        XCTAssertThrowsError(try service.imagesToPDF(urls: [fakeURL], outputName: "test")) { error in
            XCTAssertTrue(error is ConverterError)
        }
    }

    func testImagesToPDF_multipleImages() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50))
        var urls: [URL] = []

        for i in 0..<3 {
            let img = renderer.image { ctx in
                UIColor.blue.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
            }
            let path = FileManager.default.temporaryDirectory.appendingPathComponent("multi_img_\(i)_\(UUID().uuidString).png")
            try img.pngData()?.write(to: path)
            urls.append(path)
        }

        let result = try service.imagesToPDF(urls: urls, outputName: "multi_img_test_\(UUID().uuidString)")
        let doc = PDFDocument(url: result.url)
        XCTAssertEqual(doc!.pageCount, 3)

        for url in urls { try? FileManager.default.removeItem(at: url) }
        try? FileManager.default.removeItem(at: result.url)
    }

    func testDocumentToPDF_textFile() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_doc_\(UUID().uuidString).txt")
        try "Hello World\nLine 2\nLine 3".write(to: tempFile, atomically: true, encoding: .utf8)

        let result = try service.documentToPDF(url: tempFile, outputName: "txt_to_pdf_\(UUID().uuidString)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))

        let doc = PDFDocument(url: result.url)
        XCTAssertNotNil(doc)
        XCTAssertGreaterThan(doc!.pageCount, 0)

        try? FileManager.default.removeItem(at: tempFile)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testDocumentToPDF_csvFile() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).csv")
        try "Name,Age\nAlice,30\nBob,25".write(to: tempFile, atomically: true, encoding: .utf8)

        let result = try service.documentToPDF(url: tempFile, outputName: "csv_to_pdf_\(UUID().uuidString)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))

        try? FileManager.default.removeItem(at: tempFile)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testDocumentToPDF_officeDoc() throws {
        // Create a fake docx (just text) - will use officeDocToPDF path
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).docx")
        try "Office document content".write(to: tempFile, atomically: true, encoding: .utf8)

        let result = try service.documentToPDF(url: tempFile, outputName: "doc_to_pdf_\(UUID().uuidString)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))

        try? FileManager.default.removeItem(at: tempFile)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testPdfToImages_jpg() throws {
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        if let page = PDFPage(image: image) {
            doc.insert(page, at: 0)
            doc.insert(page, at: 1)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("images_test_\(UUID().uuidString).pdf")
        doc.write(to: url)

        let results = try service.pdfToImages(url: url, format: .jpg, outputDir: "")
        XCTAssertEqual(results.count, 2)

        for result in results {
            XCTAssertTrue(result.url.lastPathComponent.hasSuffix(".jpg"))
            try? FileManager.default.removeItem(at: result.url)
        }
        try? FileManager.default.removeItem(at: url)
    }

    func testPdfToImages_png() throws {
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        if let page = PDFPage(image: image) { doc.insert(page, at: 0) }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("png_test_\(UUID().uuidString).pdf")
        doc.write(to: url)

        let results = try service.pdfToImages(url: url, format: .png, outputDir: "")
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].url.lastPathComponent.hasSuffix(".png"))

        for result in results { try? FileManager.default.removeItem(at: result.url) }
        try? FileManager.default.removeItem(at: url)
    }

    func testPdfToImages_cannotOpenFile() {
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("nope.pdf")
        XCTAssertThrowsError(try service.pdfToImages(url: fakeURL, format: .jpg, outputDir: "")) { error in
            XCTAssertTrue(error is ConverterError)
        }
    }

    func testPdfToText_withContent() throws {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            let text = "Testing PDF text extraction here" as NSString
            text.draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("text_ext_\(UUID().uuidString).pdf")
        try data.write(to: url)

        let text = try service.pdfToText(url: url)
        XCTAssertTrue(text.contains("Testing"))

        try? FileManager.default.removeItem(at: url)
    }

    func testSaveTextFile_collision() throws {
        let name = "collision_txt_\(UUID().uuidString)"
        let result1 = try service.saveTextFile(text: "First", outputName: name)
        let result2 = try service.saveTextFile(text: "Second", outputName: name)

        XCTAssertNotEqual(result1.url, result2.url)

        try? FileManager.default.removeItem(at: result1.url)
        try? FileManager.default.removeItem(at: result2.url)
    }

    func testImageFormat_identifiable() {
        XCTAssertEqual(ConverterService.ImageFormat.jpg.id, "JPG")
        XCTAssertEqual(ConverterService.ImageFormat.png.id, "PNG")
    }
}

// MARK: - OCRService Tests

final class OCRServiceTests: XCTestCase {
    let service = OCRService.shared

    func testExtractTextFromImage_withText() async throws {
        // Create an image with text drawn on it
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
            let text = "Hello World Test OCR" as NSString
            text.draw(at: CGPoint(x: 20, y: 50), withAttributes: [
                .font: UIFont.systemFont(ofSize: 36),
                .foregroundColor: UIColor.black
            ])
        }

        let result = try await service.extractTextFromImage(image)
        // OCR should detect some text
        XCTAssertFalse(result.isEmpty)
    }

    func testExtractText_fromPDF_withNativeText() async throws {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            let text = "This is native PDF text for OCR testing" as NSString
            text.draw(at: CGPoint(x: 50, y: 50), withAttributes: [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ])
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ocr_pdf_\(UUID().uuidString).pdf")
        try data.write(to: url)

        let result = try await service.extractText(from: url)
        XCTAssertTrue(result.contains("native"))

        try? FileManager.default.removeItem(at: url)
    }

    func testExtractText_cannotOpenPDF() async {
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent_ocr.pdf")
        do {
            _ = try await service.extractText(from: fakeURL)
            XCTFail("Expected OCRError to be thrown")
        } catch {
            XCTAssertTrue(error is OCRError)
        }
    }

    func testExtractText_cannotLoadImage() async {
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent.jpg")
        do {
            _ = try await service.extractText(from: fakeURL)
            XCTFail("Expected OCRError to be thrown")
        } catch {
            XCTAssertTrue(error is OCRError)
        }
    }
}

// MARK: - Extended ChatViewModel Tests

@MainActor
final class ChatViewModelExtendedTests: XCTestCase {
    var viewModel: ChatViewModel!
    var container: ModelContainer!

    override func setUp() {
        super.setUp()
        viewModel = ChatViewModel()
        container = try! ModelContainer(for: Conversation.self, ChatMessage.self, DocumentFile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testHandleAction_openTool() {
        let coordinator = ChatToolCoordinator()
        let router = NavigationRouter()
        let action = ChatAction(label: "Open", icon: "doc", actionType: .openTool, toolId: "Scanner")

        viewModel.handleAction(action, coordinator: coordinator, router: router, context: container.mainContext)
        XCTAssertTrue(coordinator.showScanner)
    }

    func testHandleAction_openTool_merge_agentic() {
        let coordinator = ChatToolCoordinator()
        let router = NavigationRouter()
        let action = ChatAction(label: "Merge", icon: "doc", actionType: .openTool, toolId: "Merge PDF")

        viewModel.handleAction(action, coordinator: coordinator, router: router, context: container.mainContext)
        // Merge now uses agentic flow (chat-based) instead of opening a sheet
        XCTAssertNil(coordinator.activeTool)
        XCTAssertEqual(viewModel.pendingAgenticTool, "Merge PDF")
    }

    func testHandleAction_navigateTab_tools() {
        let coordinator = ChatToolCoordinator()
        let router = NavigationRouter()
        let action = ChatAction(label: "Tools", icon: "wrench", actionType: .navigateTab, tabId: "tools")

        viewModel.handleAction(action, coordinator: coordinator, router: router, context: container.mainContext)
        XCTAssertEqual(router.selectedTab, .tools)
    }

    func testHandleAction_navigateTab_settings() {
        let coordinator = ChatToolCoordinator()
        let router = NavigationRouter()
        let action = ChatAction(label: "Settings", icon: "gearshape", actionType: .navigateTab, tabId: "settings")

        viewModel.handleAction(action, coordinator: coordinator, router: router, context: container.mainContext)
        XCTAssertEqual(router.selectedTab, .settings)
    }

    func testHandleAction_navigateTab_unknown() {
        let coordinator = ChatToolCoordinator()
        let router = NavigationRouter()
        router.selectedTab = .chat
        let action = ChatAction(label: "Unknown", icon: "x", actionType: .navigateTab, tabId: "unknown")

        viewModel.handleAction(action, coordinator: coordinator, router: router, context: container.mainContext)
        XCTAssertEqual(router.selectedTab, .chat) // unchanged
    }

    func testHandleAction_openFile() {
        let coordinator = ChatToolCoordinator()
        let router = NavigationRouter()
        router.selectedTab = .chat
        let action = ChatAction(label: "File", icon: "doc", actionType: .openFile, fileId: "123")

        viewModel.handleAction(action, coordinator: coordinator, router: router, context: container.mainContext)
        // openFile now triggers ShareService directly (no tab navigation)
        XCTAssertEqual(router.selectedTab, .chat)
    }

    func testHandleAction_showResult() {
        let coordinator = ChatToolCoordinator()
        let router = NavigationRouter()
        let action = ChatAction(label: "Result", icon: "checkmark", actionType: .showResult)

        // Should not crash - it's a no-op
        viewModel.handleAction(action, coordinator: coordinator, router: router, context: container.mainContext)
    }

    func testMessagesForCurrentConversation_withMessages() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Conversation.self, ChatMessage.self, configurations: config)
        let context = ModelContext(container)

        let conv = Conversation(title: "Test")
        context.insert(conv)
        viewModel.currentConversation = conv

        let msg1 = ChatMessage(content: "Hello", role: "user", conversation: conv)
        let msg2 = ChatMessage(content: "Hi!", role: "assistant", conversation: conv)
        let otherConv = Conversation()
        let otherConvMsg = ChatMessage(content: "Unrelated", role: "user", conversation: otherConv)

        let allMessages = [msg1, msg2, otherConvMsg]
        let filtered = viewModel.messagesForCurrentConversation(allMessages: allMessages)

        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.first?.role, "user")
        XCTAssertEqual(filtered.last?.role, "assistant")
    }

    func testQuickActionProperties() {
        XCTAssertEqual(viewModel.actions.count, 6)

        let scanAction = viewModel.actions.first { $0.label == "Scan" }
        XCTAssertNotNil(scanAction)
        XCTAssertEqual(scanAction?.icon, "doc.viewfinder")
        XCTAssertEqual(scanAction?.toolId, "Scanner")
        XCTAssertEqual(scanAction?.prompt, "Scan a document")
    }

    func testInputTextMutation() {
        viewModel.inputText = "Test message"
        XCTAssertEqual(viewModel.inputText, "Test message")
    }
}

// MARK: - Extended AIDocumentViewModel Tests

@MainActor
final class AIDocumentViewModelExtendedTests: XCTestCase {
    var viewModel: AIDocumentViewModel!

    override func setUp() {
        super.setUp()
        viewModel = AIDocumentViewModel()
    }

    func testAskQuestion_withDocument() {
        viewModel.extractedDocumentText = "The capital of France is Paris. Paris is known for the Eiffel Tower and fine cuisine."

        viewModel.askQuestion("capital")
        // The question is processed via keyword search (no AI on simulator)
        XCTAssertEqual(viewModel.chatMessages.count, 1) // user message added synchronously
        XCTAssertEqual(viewModel.chatMessages[0].role, "user")
    }

    func testAskQuestion_emptyDocument_noOp() {
        viewModel.extractedDocumentText = nil
        viewModel.askQuestion("test")
        XCTAssertTrue(viewModel.chatMessages.isEmpty)
    }

    func testSaveResultAsText_nilResult() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, configurations: config)
        let context = ModelContext(container)

        viewModel.resultText = nil
        viewModel.saveResultAsText(outputName: "test", context: context)
        // Should be a no-op
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertNil(viewModel.resultFileName)
    }

    func testSaveResultAsText_withResult() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, configurations: config)
        let context = ModelContext(container)

        viewModel.resultText = "This is a test summary result"
        viewModel.saveResultAsText(outputName: "ai_result_\(UUID().uuidString)", context: context)

        XCTAssertNotNil(viewModel.resultFileName)
        XCTAssertFalse(viewModel.isProcessing)
    }
}

// MARK: - Extended PDFToolsViewModel Tests

@MainActor
final class PDFToolsViewModelExtendedTests: XCTestCase {
    var viewModel: PDFToolsViewModel!

    override func setUp() {
        super.setUp()
        viewModel = PDFToolsViewModel()
    }

    func testReadMetadata_validPDF() throws {
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        if let page = PDFPage(image: image) { doc.insert(page, at: 0) }

        doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] = "VM Test"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vm_meta_\(UUID().uuidString).pdf")
        doc.write(to: url)

        let metadata = viewModel.readMetadata(url: url)
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.title, "VM Test")

        try? FileManager.default.removeItem(at: url)
    }

    func testReadMetadata_invalidURL() {
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("nope_meta.pdf")
        let metadata = viewModel.readMetadata(url: fakeURL)
        XCTAssertNil(metadata)
    }
}

// MARK: - Design System Tests

final class AppSpacingTests: XCTestCase {
    func testValues() {
        XCTAssertEqual(AppSpacing.xs, 4)
        XCTAssertEqual(AppSpacing.sm, 8)
        XCTAssertEqual(AppSpacing.md, 16)
        XCTAssertEqual(AppSpacing.lg, 24)
        XCTAssertEqual(AppSpacing.xl, 32)
        XCTAssertEqual(AppSpacing.xxl, 48)
    }
}

final class AppCornerRadiusTests: XCTestCase {
    func testValues() {
        XCTAssertEqual(AppCornerRadius.sm, 8)
        XCTAssertEqual(AppCornerRadius.md, 12)
        XCTAssertEqual(AppCornerRadius.lg, 16)
        XCTAssertEqual(AppCornerRadius.xl, 24)
    }
}

final class AppAnimationsTests: XCTestCase {
    func testAnimationsExist() {
        // Just verify they can be accessed without crashing
        _ = AppAnimations.springBounce
        _ = AppAnimations.springSmooth
        _ = AppAnimations.springQuick
        _ = AppAnimations.easeOut
        _ = AppAnimations.easeInOut
        _ = AppAnimations.slowEase
    }

    func testStagger() {
        let animation = AppAnimations.stagger(index: 3)
        XCTAssertNotNil(animation)
    }

    func testStaggerDifferentIndices() {
        let a0 = AppAnimations.stagger(index: 0)
        let a5 = AppAnimations.stagger(index: 5)
        // Different indices should produce different animations (different delays)
        XCTAssertNotNil(a0)
        XCTAssertNotNil(a5)
    }
}

final class AppColorsTests: XCTestCase {
    func testAllColorsAccessible() {
        _ = Color.appPrimary
        _ = Color.appPrimaryLight
        _ = Color.appAccent
        _ = Color.appSuccess
        _ = Color.appWarning
        _ = Color.appDanger
        _ = Color.appBGDark
        _ = Color.appBGCard
        _ = Color.appText
        _ = Color.appTextMuted
        _ = Color.appTextDim
        _ = Color.appBorder
        _ = Color.appBGElevated
        _ = Color.appGlassStroke
    }

    func testGradients() {
        _ = Color.appGradientPrimary
        _ = Color.appGradientAccent
        _ = Color.appGradientSuccess
        _ = Color.appGradientDanger
    }
}

final class AppTypographyTests: XCTestCase {
    func testAllFontsAccessible() {
        _ = Font.appH1
        _ = Font.appH2
        _ = Font.appH3
        _ = Font.appBody
        _ = Font.appCaption
        _ = Font.appMicro
        _ = Font.appMono
    }
}

// MARK: - Extended ConverterViewModel Tests

@MainActor
final class ConverterViewModelExtendedTests: XCTestCase {
    var viewModel: ConverterViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ConverterViewModel()
    }

    func testPdfToText_validPDF() throws {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            let text = "Converter test text content" as NSString
            text.draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("conv_test_\(UUID().uuidString).pdf")
        try data.write(to: url)

        viewModel.pdfToText(url: url)
        XCTAssertTrue(viewModel.didComplete)
        XCTAssertNotNil(viewModel.extractedText)
        XCTAssertTrue(viewModel.extractedText!.contains("Converter"))
        XCTAssertFalse(viewModel.isProcessing)

        try? FileManager.default.removeItem(at: url)
    }

    func testPdfToText_invalidPDF() {
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("bad.pdf")
        viewModel.pdfToText(url: fakeURL)
        XCTAssertTrue(viewModel.showError)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isProcessing)
    }

    func testSaveExtractedText_nilText() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, configurations: config)
        let context = ModelContext(container)

        viewModel.extractedText = nil
        viewModel.saveExtractedText(outputName: "test", context: context)
        XCTAssertNil(viewModel.resultFileName) // Should be no-op
    }

    func testSaveExtractedText_validText() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, configurations: config)
        let context = ModelContext(container)

        viewModel.extractedText = "Extracted text content for saving"
        viewModel.saveExtractedText(outputName: "save_test_\(UUID().uuidString)", context: context)
        XCTAssertNotNil(viewModel.resultFileName)
        XCTAssertTrue(viewModel.didComplete)
    }

    func testImagesToPDF() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, configurations: config)
        let context = ModelContext(container)

        // Create test image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let imgPath = FileManager.default.temporaryDirectory.appendingPathComponent("vm_img_\(UUID().uuidString).jpg")
        try image.jpegData(compressionQuality: 0.9)?.write(to: imgPath)

        viewModel.imagesToPDF(urls: [imgPath], outputName: "vm_img_to_pdf_\(UUID().uuidString)", context: context)
        XCTAssertTrue(viewModel.didComplete)
        XCTAssertNotNil(viewModel.resultFileName)

        try? FileManager.default.removeItem(at: imgPath)
    }

    func testDocumentToPDF() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, configurations: config)
        let context = ModelContext(container)

        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("vm_doc_\(UUID().uuidString).txt")
        try "Test document content".write(to: tempFile, atomically: true, encoding: .utf8)

        viewModel.documentToPDF(url: tempFile, outputName: "vm_doc_to_pdf_\(UUID().uuidString)", context: context)
        XCTAssertTrue(viewModel.didComplete)
        XCTAssertNotNil(viewModel.resultFileName)

        try? FileManager.default.removeItem(at: tempFile)
    }

    func testPdfToImages() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, configurations: config)
        let context = ModelContext(container)

        // Create a test PDF
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        if let page = PDFPage(image: img) { doc.insert(page, at: 0) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vm_pdf_img_\(UUID().uuidString).pdf")
        doc.write(to: url)

        viewModel.pdfToImages(url: url, format: .jpg, context: context)
        XCTAssertTrue(viewModel.didComplete)
        XCTAssertNotNil(viewModel.resultFileName)

        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Extended KeywordMatchingProvider Tests

@MainActor
final class KeywordMatchingProviderExtendedTests: XCTestCase {
    let provider = KeywordMatchingProvider()

    func testOCRKeyword() async throws {
        let response = try await provider.generateResponse(for: "extract text with OCR", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "OCR")
    }

    func testWatermarkKeyword() async throws {
        let response = try await provider.generateResponse(for: "watermark my document", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Watermark")
    }

    func testRotateKeyword() async throws {
        let response = try await provider.generateResponse(for: "rotate the PDF", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Rotate PDF")
    }

    func testReorderKeyword() async throws {
        let response = try await provider.generateResponse(for: "reorder pages", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Reorder Pages")
    }

    func testPageNumberKeyword() async throws {
        let response = try await provider.generateResponse(for: "add page numbers", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Page Numbers")
    }

    func testExtractKeyword() async throws {
        let response = try await provider.generateResponse(for: "extract some pages", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Extract Pages")
    }

    func testSplitKeyword() async throws {
        let response = try await provider.generateResponse(for: "split my PDF into parts", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Split PDF")
    }

    func testResetSession() {
        // Should not crash
        provider.resetSession()
    }
}

// MARK: - Extended AIService Tests

@MainActor
final class AIServiceExtendedTests: XCTestCase {
    func testStreamResponse() async throws {
        let service = AIService.shared
        var partials: [String] = []
        let response = try await service.streamResponse(
            for: "scan a document",
            conversationHistory: []
        ) { partial in
            partials.append(partial)
        }
        XCTAssertFalse(response.text.isEmpty)
        XCTAssertEqual(response.toolBadge, "Scanner")
    }

    func testResetSession() {
        AIService.shared.resetSession()
        // Should not crash
    }

    func testBackendIsKeywordOnSimulator() {
        #if targetEnvironment(simulator)
        XCTAssertEqual(AIService.shared.activeBackend, .keywordMatching)
        #endif
    }
}

// MARK: - FileMetadataService Extended Tests

final class FileMetadataServiceExtendedTests: XCTestCase {
    let service = FileMetadataService.shared

    func testExtractMetadata_pdfFile() throws {
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        if let page = PDFPage(image: image) {
            doc.insert(page, at: 0)
            doc.insert(page, at: 1)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("meta_pdf_\(UUID().uuidString).pdf")
        doc.write(to: url)

        let metadata = service.extractMetadata(from: url)
        XCTAssertGreaterThan(metadata.fileSize, 0)
        XCTAssertEqual(metadata.pageCount, 2)
        XCTAssertNotNil(metadata.createdAt)
        XCTAssertNotNil(metadata.modifiedAt)

        try? FileManager.default.removeItem(at: url)
    }

    func testExtractMetadata_nonExistentFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent_meta_xyz.pdf")
        let metadata = service.extractMetadata(from: url)
        XCTAssertEqual(metadata.fileSize, 0)
        XCTAssertNil(metadata.pageCount)
    }
}

// MARK: - ToolItem Extended Tests

final class ToolItemExtendedTests: XCTestCase {

    func testSections() {
        XCTAssertEqual(ToolItem.scanner.section, "Scanner")
        XCTAssertEqual(ToolItem.mergePDF.section, "PDF Tools")
        XCTAssertEqual(ToolItem.imageToPDF.section, "Converters")
        XCTAssertEqual(ToolItem.summarizePDF.section, "AI Tools")
        XCTAssertEqual(ToolItem.emailPDF.section, "Utilities")
    }

    func testColors() {
        for tool in ToolItem.allCases {
            // Should not crash
            _ = tool.color
        }
    }

    func testAllSectionsPresent() {
        let sections = Set(ToolItem.allCases.map { $0.section })
        XCTAssertTrue(sections.contains("Scanner"))
        XCTAssertTrue(sections.contains("PDF Tools"))
        XCTAssertTrue(sections.contains("Converters"))
        XCTAssertTrue(sections.contains("AI Tools"))
        XCTAssertTrue(sections.contains("Utilities"))
    }

    func testScannerCount() {
        let scannerTools = ToolItem.allCases.filter { $0.section == "Scanner" }
        XCTAssertEqual(scannerTools.count, 1)
    }

    func testPDFToolsCount() {
        let pdfTools = ToolItem.allCases.filter { $0.section == "PDF Tools" }
        XCTAssertEqual(pdfTools.count, 14)
    }

    func testConvertersCount() {
        let converters = ToolItem.allCases.filter { $0.section == "Converters" }
        XCTAssertEqual(converters.count, 4)
    }

    func testAIToolsCount() {
        let aiTools = ToolItem.allCases.filter { $0.section == "AI Tools" }
        XCTAssertEqual(aiTools.count, 3)
    }

    func testUtilitiesCount() {
        let utilities = ToolItem.allCases.filter { $0.section == "Utilities" }
        XCTAssertEqual(utilities.count, 1)
    }
}

// MARK: - PDFMetadata Tests

final class PDFMetadataTests: XCTestCase {

    func testInit() {
        let metadata = PDFMetadata(title: "Test", author: "Author", subject: "Subject", keywords: "a, b")
        XCTAssertEqual(metadata.title, "Test")
        XCTAssertEqual(metadata.author, "Author")
        XCTAssertEqual(metadata.subject, "Subject")
        XCTAssertEqual(metadata.keywords, "a, b")
    }

    func testEmptyInit() {
        let metadata = PDFMetadata(title: "", author: "", subject: "", keywords: "")
        XCTAssertTrue(metadata.title.isEmpty)
        XCTAssertTrue(metadata.author.isEmpty)
    }

    func testMutation() {
        var metadata = PDFMetadata(title: "Old", author: "", subject: "", keywords: "")
        metadata.title = "New"
        XCTAssertEqual(metadata.title, "New")
    }
}

// MARK: - Extended PDFToolsService Tests

@MainActor
final class PDFToolsServiceExtendedTests: XCTestCase {
    let service = PDFToolsService.shared

    private func createTestPDF(pageCount: Int = 3) throws -> URL {
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 300))
        for i in 0..<pageCount {
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
                let text = "Page \(i + 1)" as NSString
                text.draw(at: CGPoint(x: 50, y: 150), withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
            if let page = PDFPage(image: image) { doc.insert(page, at: i) }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ext_test_\(UUID().uuidString).pdf")
        doc.write(to: url)
        return url
    }

    func testCompressPDF_low() async throws {
        let pdf = try createTestPDF(pageCount: 1)
        let result = try await service.compressPDF(from: pdf, level: .low, outputName: "comp_low_\(UUID().uuidString)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testCompressPDF_medium() async throws {
        let pdf = try createTestPDF(pageCount: 1)
        let result = try await service.compressPDF(from: pdf, level: .medium, outputName: "comp_med_\(UUID().uuidString)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testExtractPages_invalidIndices() async throws {
        let pdf = try createTestPDF(pageCount: 3)
        do {
            _ = try await service.extractPages(from: pdf, pageIndices: [10, 20], outputName: "bad")
            XCTFail("Expected error for invalid page indices")
        } catch {
            XCTAssertTrue(error is PDFToolsError)
        }
        try? FileManager.default.removeItem(at: pdf)
    }

    func testMergePDFs_singleFile() async throws {
        let pdf = try createTestPDF(pageCount: 2)
        let result = try await service.mergePDFs(from: [pdf], outputName: "merge_single_\(UUID().uuidString)")
        let doc = PDFDocument(url: result.url)
        XCTAssertEqual(doc!.pageCount, 2)
        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testRotatePDF_180() async throws {
        let pdf = try createTestPDF(pageCount: 1)
        let result = try await service.rotatePDF(from: pdf, degrees: 180, outputName: "rot180_\(UUID().uuidString)")
        let doc = PDFDocument(url: result.url)
        XCTAssertEqual(doc!.page(at: 0)!.rotation, 180)
        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testRotatePDF_270() async throws {
        let pdf = try createTestPDF(pageCount: 1)
        let result = try await service.rotatePDF(from: pdf, degrees: 270, outputName: "rot270_\(UUID().uuidString)")
        let doc = PDFDocument(url: result.url)
        XCTAssertEqual(doc!.page(at: 0)!.rotation, 270)
        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }

    func testCompressionLevel_allCases() {
        XCTAssertEqual(PDFToolsService.CompressionLevel.allCases.count, 3)
    }

    func testCompressionLevel_identifiable() {
        XCTAssertEqual(PDFToolsService.CompressionLevel.low.id, "Low")
        XCTAssertEqual(PDFToolsService.CompressionLevel.medium.id, "Medium")
        XCTAssertEqual(PDFToolsService.CompressionLevel.high.id, "High")
    }

    func testWriteMetadata_emptyValues() async throws {
        let pdf = try createTestPDF(pageCount: 1)
        let metadata = PDFMetadata(title: "", author: "", subject: "", keywords: "")
        let result = try await service.writeMetadata(to: pdf, metadata: metadata, outputName: "empty_meta_\(UUID().uuidString)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        try? FileManager.default.removeItem(at: pdf)
        try? FileManager.default.removeItem(at: result.url)
    }
}

// MARK: - ScannerService Extended Tests

@MainActor
final class ScannerServiceExtendedTests: XCTestCase {
    let service = ScannerService.shared

    private func createTestImage(color: UIColor = .red, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func testRotate180() {
        let image = createTestImage()
        let rotated = service.rotateImage(image, by: 180)
        XCTAssertGreaterThan(rotated.size.width, 0)
    }

    func testRotate270() {
        let image = createTestImage()
        let rotated = service.rotateImage(image, by: 270)
        XCTAssertGreaterThan(rotated.size.width, 0)
    }

    func testRotate360() {
        let image = createTestImage()
        let rotated = service.rotateImage(image, by: 360)
        XCTAssertGreaterThan(rotated.size.width, 0)
    }

    func testGeneratePDF_multiplePages() {
        let images = (0..<5).map { _ in createTestImage() }
        let pages = images.map { ScannedPage(image: $0) }
        let data = service.generatePDF(from: pages)
        XCTAssertNotNil(data)

        // Verify it's a valid PDF
        let doc = PDFDocument(data: data!)
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc!.pageCount, 5)
    }

    func testApplyFilter_allFilters() {
        let image = createTestImage()
        for filter in ScanFilter.allCases {
            let result = service.applyFilter(filter, to: image)
            XCTAssertGreaterThan(result.size.width, 0, "Failed for filter: \(filter.rawValue)")
        }
    }

    func testSaveScanAsPDF_multiplePages() throws {
        let images = [createTestImage(color: .red), createTestImage(color: .blue)]
        let pages = images.map { ScannedPage(image: $0) }
        let result = try service.saveScanAsPDF(pages: pages, fileName: "multi_scan_\(UUID().uuidString)")

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        let doc = PDFDocument(url: result.url)
        XCTAssertEqual(doc?.pageCount, 2)

        try? FileManager.default.removeItem(at: result.url)
    }
}

// MARK: - FilesViewModel Extended Tests

@MainActor
final class FilesViewModelExtendedTests: XCTestCase {
    var viewModel: FilesViewModel!

    override func setUp() {
        super.setUp()
        viewModel = FilesViewModel()
    }

    func testFilteredAndSorted_sortBySizeAsc() {
        let small = DocumentFile(name: "Small", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        let large = DocumentFile(name: "Large", fileExtension: "pdf", relativeFilePath: "", fileSize: 9000)

        viewModel.sortOption = .sizeAsc
        let sorted = viewModel.filteredAndSorted([large, small])
        XCTAssertEqual(sorted.first?.name, "Small")
    }

    func testFilteredAndSorted_sortByDateAsc() {
        let old = DocumentFile(name: "Old", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        old.importedAt = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let recent = DocumentFile(name: "New", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)

        viewModel.sortOption = .dateAsc
        let sorted = viewModel.filteredAndSorted([recent, old])
        XCTAssertEqual(sorted.first?.name, "Old")
    }

    func testFilteredAndSorted_emptySearch() {
        let file = DocumentFile(name: "Test", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        viewModel.searchText = ""
        let result = viewModel.filteredAndSorted([file])
        XCTAssertEqual(result.count, 1)
    }

    func testFilteredAndSorted_noMatch() {
        let file = DocumentFile(name: "Test", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
        viewModel.searchText = "zzzzzzz"
        let result = viewModel.filteredAndSorted([file])
        XCTAssertTrue(result.isEmpty)
    }

    func testFilteredAndSorted_docCategory() {
        let doc = DocumentFile(name: "Report", fileExtension: "docx", relativeFilePath: "", fileSize: 100)
        let pdf = DocumentFile(name: "Invoice", fileExtension: "pdf", relativeFilePath: "", fileSize: 200)

        viewModel.selectedCategory = .doc
        let filtered = viewModel.filteredAndSorted([doc, pdf])
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "Report")
    }

    func testCategoryCount_allCategories() {
        let files = [
            DocumentFile(name: "A", fileExtension: "pdf", relativeFilePath: "", fileSize: 100),
            DocumentFile(name: "B", fileExtension: "jpg", relativeFilePath: "", fileSize: 100),
            DocumentFile(name: "C", fileExtension: "docx", relativeFilePath: "", fileSize: 100),
            DocumentFile(name: "D", fileExtension: "xlsx", relativeFilePath: "", fileSize: 100),
            DocumentFile(name: "E", fileExtension: "pptx", relativeFilePath: "", fileSize: 100),
            DocumentFile(name: "F", fileExtension: "txt", relativeFilePath: "", fileSize: 100),
        ]

        XCTAssertEqual(viewModel.categoryCount(.all, in: files), 6)
        XCTAssertEqual(viewModel.categoryCount(.pdf, in: files), 1)
        XCTAssertEqual(viewModel.categoryCount(.img, in: files), 1)
        XCTAssertEqual(viewModel.categoryCount(.doc, in: files), 1)
        XCTAssertEqual(viewModel.categoryCount(.xls, in: files), 1)
        XCTAssertEqual(viewModel.categoryCount(.ppt, in: files), 1)
        XCTAssertEqual(viewModel.categoryCount(.txt, in: files), 1)
    }

    func testRecentFiles_limitExceeded() {
        let now = Date.now
        var files: [DocumentFile] = []
        for i in 0..<10 {
            let file = DocumentFile(name: "File\(i)", fileExtension: "pdf", relativeFilePath: "", fileSize: 100)
            file.lastOpenedAt = Calendar.current.date(byAdding: .minute, value: -i, to: now)
            files.append(file)
        }

        let recent = viewModel.recentFiles(files, limit: 3)
        XCTAssertEqual(recent.count, 3)
    }

    func testRecentFiles_emptyList() {
        let recent = viewModel.recentFiles([], limit: 5)
        XCTAssertTrue(recent.isEmpty)
    }
}

// MARK: - Extended Error Tests

final class ExtendedErrorTests: XCTestCase {

    func testFileStorageError_allCases() {
        let errors: [FileStorageError] = [.nameAlreadyExists, .fileNotFound]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testPDFToolsError_allCases() {
        let errors: [PDFToolsError] = [.cannotOpenPDF, .noValidPages, .invalidPageRange, .incorrectPassword, .saveFailed]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testOCRError_allCases() {
        let errors: [OCRError] = [.cannotLoadImage, .cannotOpenPDF, .noTextFound]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testConverterError_allCases() {
        let errors: [ConverterError] = [.noValidInput, .cannotOpenFile, .conversionFailed, .noTextContent]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testScannerError_allCases() {
        let errors: [ScannerError] = [.pdfGenerationFailed, .saveFailed]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - TipKit Tests

final class AppTipsTests: XCTestCase {

    func testTryAIToolsTip_properties() {
        let tip = TryAIToolsTip()
        XCTAssertNotNil(tip.title)
        XCTAssertNotNil(tip.message)
        XCTAssertNotNil(tip.image)
    }

    func testChatWelcomeTip_properties() {
        let tip = ChatWelcomeTip()
        XCTAssertNotNil(tip.title)
        XCTAssertNotNil(tip.message)
        XCTAssertNotNil(tip.image)
    }

    func testScanCompleteTip_properties() {
        let tip = ScanCompleteTip()
        XCTAssertNotNil(tip.title)
        XCTAssertNotNil(tip.message)
        XCTAssertNotNil(tip.image)
    }

    func testTipEvents_exist() {
        // Verify events are accessible
        _ = TryAIToolsTip.toolsTabVisited
        _ = ChatWelcomeTip.chatTabVisited
        _ = ScanCompleteTip.scanCompleted
    }
}

// MARK: - Constants Extended Tests

final class ConstantsExtendedTests: XCTestCase {

    func testSupportedExtensions_comprehensive() {
        let expected: Set<String> = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
                                      "txt", "csv", "xml", "rtf",
                                      "jpg", "jpeg", "png", "heic", "webp", "bmp", "gif", "tiff"]
        for ext in expected {
            XCTAssertTrue(AppConstants.supportedExtensions.contains(ext), "Missing extension: \(ext)")
        }
    }

    func testSupportedUTTypes_nonEmpty() {
        XCTAssertGreaterThan(AppConstants.supportedUTTypes.count, 10)
    }
}

// MARK: - QuickAction Extended Tests

final class QuickActionExtendedTests: XCTestCase {

    func testAllFields() {
        let action = QuickAction(label: "Test", icon: "star", prompt: "Do test", toolId: "Scanner")
        XCTAssertNotNil(action.id)
        XCTAssertEqual(action.label, "Test")
        XCTAssertEqual(action.icon, "star")
        XCTAssertEqual(action.prompt, "Do test")
        XCTAssertEqual(action.toolId, "Scanner")
    }

    func testOptionalToolId() {
        let action = QuickAction(label: "X", icon: "x", prompt: "p")
        XCTAssertNil(action.toolId)
    }

    func testUniqueIds() {
        let a1 = QuickAction(label: "A", icon: "a", prompt: "a")
        let a2 = QuickAction(label: "A", icon: "a", prompt: "a")
        XCTAssertNotEqual(a1.id, a2.id)
    }
}

// MARK: - AIResponse Extended Tests

final class AIResponseExtendedTests: XCTestCase {

    func testAllActionTypes() {
        let actions = [
            ChatAction(label: "A", icon: "a", actionType: .openTool, toolId: "Scanner"),
            ChatAction(label: "B", icon: "b", actionType: .navigateTab, tabId: "settings"),
            ChatAction(label: "C", icon: "c", actionType: .openFile, fileId: "123"),
            ChatAction(label: "D", icon: "d", actionType: .showResult),
        ]
        let response = AIResponse(text: "Test", toolBadge: nil, actions: actions)
        XCTAssertEqual(response.actions.count, 4)
    }

    func testLongText() {
        let longText = String(repeating: "Hello world. ", count: 1000)
        let response = AIResponse(text: longText, toolBadge: "Test", actions: [])
        XCTAssertEqual(response.text.count, longText.count)
    }
}

// MARK: - Integration Tests

@MainActor
final class PDFWorkflowIntegrationTests: XCTestCase {
    let pdfService = PDFToolsService.shared
    let converterService = ConverterService.shared
    let scannerService = ScannerService.shared

    func testScanToCompressWorkflow() async throws {
        // 1. Scan pages
        let image = createTestImage()
        let page = ScannedPage(image: image)
        let scanResult = try scannerService.saveScanAsPDF(pages: [page], fileName: "workflow_scan_\(UUID().uuidString)")

        // 2. Compress the scanned PDF
        let compressResult = try await pdfService.compressPDF(from: scanResult.url, level: .high, outputName: "workflow_compressed_\(UUID().uuidString)")

        XCTAssertTrue(FileManager.default.fileExists(atPath: compressResult.url.path))

        // Clean up
        try? FileManager.default.removeItem(at: scanResult.url)
        try? FileManager.default.removeItem(at: compressResult.url)
    }

    func testMergeAndSplitWorkflow() async throws {
        let pdf1 = try createTestPDF(pageCount: 2)
        let pdf2 = try createTestPDF(pageCount: 3)

        // Merge
        let merged = try await pdfService.mergePDFs(from: [pdf1, pdf2], outputName: "workflow_merge_\(UUID().uuidString)")
        let mergedDoc = PDFDocument(url: merged.url)
        XCTAssertEqual(mergedDoc!.pageCount, 5)

        // Split
        let split = try await pdfService.splitPDF(from: merged.url, startPage: 1, endPage: 3, outputName: "workflow_split_\(UUID().uuidString)")
        let splitDoc = PDFDocument(url: split.url)
        XCTAssertEqual(splitDoc!.pageCount, 3)

        try? FileManager.default.removeItem(at: pdf1)
        try? FileManager.default.removeItem(at: pdf2)
        try? FileManager.default.removeItem(at: merged.url)
        try? FileManager.default.removeItem(at: split.url)
    }

    func testPdfToImagesAndBack() async throws {
        // Create PDF
        let pdf = try createTestPDF(pageCount: 2)

        // Convert to images
        let images = try converterService.pdfToImages(url: pdf, format: .jpg, outputDir: "")
        XCTAssertEqual(images.count, 2)

        // Convert images back to PDF
        let imageURLs = images.map { $0.url }
        let backToPDF = try converterService.imagesToPDF(urls: imageURLs, outputName: "workflow_roundtrip_\(UUID().uuidString)")
        let doc = PDFDocument(url: backToPDF.url)
        XCTAssertEqual(doc!.pageCount, 2)

        try? FileManager.default.removeItem(at: pdf)
        for img in images { try? FileManager.default.removeItem(at: img.url) }
        try? FileManager.default.removeItem(at: backToPDF.url)
    }

    private func createTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }

    private func createTestPDF(pageCount: Int) throws -> URL {
        let doc = PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 300))
        for i in 0..<pageCount {
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
                ("P\(i)" as NSString).draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            }
            if let page = PDFPage(image: image) { doc.insert(page, at: i) }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("integ_\(UUID().uuidString).pdf")
        doc.write(to: url)
        return url
    }
}
