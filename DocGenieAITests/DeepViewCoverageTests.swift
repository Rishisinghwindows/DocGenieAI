// DeepViewCoverageTests.swift
// Tests that render views with extended RunLoop time and multiple layout passes
// to maximize SwiftUI body evaluation coverage.

@testable import DocGenieAI
import XCTest
import SwiftUI
import SwiftData
import UIKit
import PDFKit

// MARK: - Extended Render Helper

@MainActor
private func deepRender<V: View>(_ view: V, duration: TimeInterval = 0.2) {
    let host = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = host
    window.makeKeyAndVisible()

    // Multiple layout passes at different sizes to trigger more code paths
    for size in [CGSize(width: 390, height: 844), CGSize(width: 320, height: 568), CGSize(width: 430, height: 932)] {
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }

    RunLoop.current.run(until: Date(timeIntervalSinceNow: duration))
    XCTAssertNotNil(host.view)

    // Force another layout pass after RunLoop
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

    window.isHidden = true
}

@MainActor
private func deepRenderWithContext<V: View>(_ view: V, duration: TimeInterval = 0.2) throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, configurations: config)
    let router = NavigationRouter()
    deepRender(view.environment(router).modelContainer(container), duration: duration)
}

@MainActor
private func deepRenderWithContextAndFiles<V: View>(_ view: V, fileCount: Int = 3, duration: TimeInterval = 0.2) throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, configurations: config)
    let router = NavigationRouter()

    // Insert sample files so views that show file lists have content
    for i in 0..<fileCount {
        let file = DocumentFile(
            name: "TestFile\(i)",
            fileExtension: i % 2 == 0 ? "pdf" : "jpg",
            relativeFilePath: "TestFile\(i).\(i % 2 == 0 ? "pdf" : "jpg")",
            fileSize: Int64((i + 1) * 1024),
            pageCount: i % 2 == 0 ? 5 : nil
        )
        container.mainContext.insert(file)
    }
    try container.mainContext.save()

    deepRender(view.environment(router).modelContainer(container), duration: duration)
}

private func makeTempPDF(pageCount: Int = 1) -> URL {
    let doc = PDFDocument()
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 280))
    for i in 0..<pageCount {
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 280))
            ("Page \(i+1) text" as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: [
                .font: UIFont.systemFont(ofSize: 12)
            ])
        }
        if let page = PDFPage(image: img) { doc.insert(page, at: i) }
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("deep_\(UUID().uuidString).pdf")
    doc.write(to: url)
    return url
}

// MARK: - Deep View Rendering Tests (all tool views in multiple states)

@MainActor
final class DeepToolViewRenderTests: XCTestCase {

    // OCRTextView — initial state (no file selected, no text, not processing)
    func testOCRTextViewInitial() throws {
        try deepRenderWithContext(OCRTextView(), duration: 0.3)
    }

    // OCRTextView — with files in context
    func testOCRTextViewWithFiles() throws {
        try deepRenderWithContextAndFiles(OCRTextView(), fileCount: 5, duration: 0.3)
    }

    // AskPDFView
    func testAskPDFViewInitial() throws {
        try deepRenderWithContext(AskPDFView(), duration: 0.3)
    }

    func testAskPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(AskPDFView(), fileCount: 5, duration: 0.3)
    }

    // ImageToPDFView
    func testImageToPDFViewInitial() throws {
        try deepRenderWithContext(ImageToPDFView(), duration: 0.3)
    }

    func testImageToPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(ImageToPDFView(), fileCount: 5, duration: 0.3)
    }

    // DocToPDFView
    func testDocToPDFViewInitial() throws {
        try deepRenderWithContext(DocToPDFView(), duration: 0.3)
    }

    func testDocToPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(DocToPDFView(), fileCount: 5, duration: 0.3)
    }

    // EmailPDFView
    func testEmailPDFViewInitial() throws {
        try deepRenderWithContext(EmailPDFView(), duration: 0.3)
    }

    func testEmailPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(EmailPDFView(), fileCount: 5, duration: 0.3)
    }

    // SummarizePDFView
    func testSummarizePDFViewInitial() throws {
        try deepRenderWithContext(SummarizePDFView(), duration: 0.3)
    }

    func testSummarizePDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(SummarizePDFView(), fileCount: 5, duration: 0.3)
    }

    // TranslatePDFView
    func testTranslatePDFViewInitial() throws {
        try deepRenderWithContext(TranslatePDFView(), duration: 0.3)
    }

    func testTranslatePDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(TranslatePDFView(), fileCount: 5, duration: 0.3)
    }

    // PDFToTextView
    func testPDFToTextViewInitial() throws {
        try deepRenderWithContext(PDFToTextView(), duration: 0.3)
    }

    func testPDFToTextViewWithFiles() throws {
        try deepRenderWithContextAndFiles(PDFToTextView(), fileCount: 5, duration: 0.3)
    }

    // PDFToImageView
    func testPDFToImageViewInitial() throws {
        try deepRenderWithContext(PDFToImageView(), duration: 0.3)
    }

    func testPDFToImageViewWithFiles() throws {
        try deepRenderWithContextAndFiles(PDFToImageView(), fileCount: 5, duration: 0.3)
    }

    // ReorderPDFView
    func testReorderPDFViewInitial() throws {
        try deepRenderWithContext(ReorderPDFView(), duration: 0.3)
    }

    func testReorderPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(ReorderPDFView(), fileCount: 5, duration: 0.3)
    }

    // MergePDFView
    func testMergePDFViewInitial() throws {
        try deepRenderWithContext(MergePDFView(), duration: 0.3)
    }

    func testMergePDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(MergePDFView(), fileCount: 5, duration: 0.3)
    }

    // SplitPDFView
    func testSplitPDFViewInitial() throws {
        try deepRenderWithContext(SplitPDFView(), duration: 0.3)
    }

    func testSplitPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(SplitPDFView(), fileCount: 5, duration: 0.3)
    }

    // CompressPDFView
    func testCompressPDFViewInitial() throws {
        try deepRenderWithContext(CompressPDFView(), duration: 0.3)
    }

    func testCompressPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(CompressPDFView(), fileCount: 5, duration: 0.3)
    }

    // MetadataEditorView
    func testMetadataEditorViewInitial() throws {
        try deepRenderWithContext(MetadataEditorView(), duration: 0.3)
    }

    func testMetadataEditorViewWithFiles() throws {
        try deepRenderWithContextAndFiles(MetadataEditorView(), fileCount: 5, duration: 0.3)
    }

    // SignPDFView
    func testSignPDFViewInitial() throws {
        try deepRenderWithContext(SignPDFView(), duration: 0.3)
    }

    func testSignPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(SignPDFView(), fileCount: 5, duration: 0.3)
    }

    // ExtractPagesPDFView
    func testExtractPagesPDFViewInitial() throws {
        try deepRenderWithContext(ExtractPagesPDFView(), duration: 0.3)
    }

    func testExtractPagesPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(ExtractPagesPDFView(), fileCount: 5, duration: 0.3)
    }

    // LockPDFView
    func testLockPDFViewInitial() throws {
        try deepRenderWithContext(LockPDFView(), duration: 0.3)
    }

    func testLockPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(LockPDFView(), fileCount: 5, duration: 0.3)
    }

    // UnlockPDFView
    func testUnlockPDFViewInitial() throws {
        try deepRenderWithContext(UnlockPDFView(), duration: 0.3)
    }

    func testUnlockPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(UnlockPDFView(), fileCount: 5, duration: 0.3)
    }

    // WatermarkPDFView
    func testWatermarkPDFViewInitial() throws {
        try deepRenderWithContext(WatermarkPDFView(), duration: 0.3)
    }

    func testWatermarkPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(WatermarkPDFView(), fileCount: 5, duration: 0.3)
    }

    // RotatePDFView
    func testRotatePDFViewInitial() throws {
        try deepRenderWithContext(RotatePDFView(), duration: 0.3)
    }

    func testRotatePDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(RotatePDFView(), fileCount: 5, duration: 0.3)
    }

    // CropPDFView
    func testCropPDFViewInitial() throws {
        try deepRenderWithContext(CropPDFView(), duration: 0.3)
    }

    func testCropPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(CropPDFView(), fileCount: 5, duration: 0.3)
    }

    // PageNumbersPDFView
    func testPageNumbersPDFViewInitial() throws {
        try deepRenderWithContext(PageNumbersPDFView(), duration: 0.3)
    }

    func testPageNumbersPDFViewWithFiles() throws {
        try deepRenderWithContextAndFiles(PageNumbersPDFView(), fileCount: 5, duration: 0.3)
    }
}

// MARK: - Deep Tab View Tests

@MainActor
final class DeepTabViewRenderTests: XCTestCase {

    func testChatTabViewDeep() throws {
        try deepRenderWithContext(ChatTabView(), duration: 0.5)
    }

    func testChatTabViewWithConversations() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, configurations: config)
        let router = NavigationRouter()

        // Add a conversation with messages
        let conv = Conversation()
        conv.title = "Test Chat"
        container.mainContext.insert(conv)

        let msg1 = ChatMessage(content: "Hello, how do I scan?", role: "user", conversation: conv)
        container.mainContext.insert(msg1)
        let msg2 = ChatMessage(content: "You can use the Scanner tool.", role: "assistant", conversation: conv, toolBadge: "Scanner")
        container.mainContext.insert(msg2)
        try container.mainContext.save()

        deepRender(ChatTabView().environment(router).modelContainer(container), duration: 0.5)
    }

    func testFilesTabViewDeep() throws {
        try deepRenderWithContextAndFiles(FilesTabView(), fileCount: 10, duration: 0.5)
    }

    func testFilesTabViewEmpty() throws {
        try deepRenderWithContext(FilesTabView(), duration: 0.3)
    }

    func testToolsTabViewDeep() throws {
        try deepRenderWithContext(ToolsTabView(), duration: 0.5)
    }

    func testTransferTabPlaceholderDeep() throws {
        try deepRenderWithContext(TransferTabPlaceholder(), duration: 0.3)
    }

    func testAppTabViewDeep() throws {
        try deepRenderWithContext(AppTabView(), duration: 0.5)
    }
}

// MARK: - PDFFilePickerView Deep Tests

@MainActor
final class DeepPDFFilePickerTests: XCTestCase {

    func testPDFFilePickerWithPDFFiles() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, configurations: config)

        // Insert PDF files that match the @Query filter
        for i in 0..<5 {
            let file = DocumentFile(
                name: "Document\(i)",
                fileExtension: "pdf",
                relativeFilePath: "Document\(i).pdf",
                fileSize: Int64((i + 1) * 2048),
                pageCount: i + 1
            )
            container.mainContext.insert(file)
        }
        try container.mainContext.save()

        let router = NavigationRouter()
        deepRender(
            PDFFilePickerView(title: "Select PDFs", allowsMultiple: true, selectedFiles: .constant([]))
                .environment(router)
                .modelContainer(container),
            duration: 0.3
        )
    }

    func testPDFFilePickerSingleSelection() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, configurations: config)

        for i in 0..<3 {
            let file = DocumentFile(name: "Doc\(i)", fileExtension: "pdf", relativeFilePath: "Doc\(i).pdf", fileSize: 1024)
            container.mainContext.insert(file)
        }
        try container.mainContext.save()

        let router = NavigationRouter()
        deepRender(
            PDFFilePickerView(title: "Choose PDF", allowsMultiple: false, selectedFiles: .constant([]))
                .environment(router)
                .modelContainer(container),
            duration: 0.3
        )
    }

    func testPDFFilePickerEmpty() throws {
        try deepRenderWithContext(PDFFilePickerView(title: "Select", allowsMultiple: true, selectedFiles: .constant([])), duration: 0.3)
    }
}

// MARK: - FileImportButton Deep Test

@MainActor
final class DeepFileImportButtonTests: XCTestCase {
    func testFileImportButtonDeep() throws {
        try deepRenderWithContext(FileImportButton(), duration: 0.3)
    }

    func testFileImportButtonWithFiles() throws {
        try deepRenderWithContextAndFiles(FileImportButton(), fileCount: 3, duration: 0.3)
    }
}

// MARK: - Component Deep Tests (trigger more branches)

@MainActor
final class DeepComponentTests: XCTestCase {

    func testSortMenuButton() {
        deepRender(SortMenuButton(selectedSort: .constant(.dateDesc)))
    }

    func testSortMenuButtonAllOptions() {
        for option in FileSortOption.allCases {
            deepRender(SortMenuButton(selectedSort: .constant(option)))
        }
    }

    func testConfettiView() {
        deepRender(ConfettiView(), duration: 0.3)
    }

    func testImageViewerViewDeep() {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("deep_img_\(UUID().uuidString).jpg")
        try? img.jpegData(compressionQuality: 0.8)?.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        deepRender(ImageViewerView(url: url, fileName: "TestImage.jpg"), duration: 0.3)
    }

    func testDocumentViewerRouterPDF() {
        let pdf = makeTempPDF()
        defer { try? FileManager.default.removeItem(at: pdf) }
        let file = DocumentFile(name: "Test", fileExtension: "pdf", relativeFilePath: "Test.pdf", fileSize: 1024)
        deepRender(DocumentViewerRouter(file: file), duration: 0.3)
    }

    func testDocumentViewerRouterImage() {
        let file = DocumentFile(name: "Test", fileExtension: "jpg", relativeFilePath: "Test.jpg", fileSize: 512)
        deepRender(DocumentViewerRouter(file: file), duration: 0.3)
    }

    func testDocumentViewerRouterText() {
        let file = DocumentFile(name: "Test", fileExtension: "txt", relativeFilePath: "Test.txt", fileSize: 256)
        deepRender(DocumentViewerRouter(file: file), duration: 0.3)
    }

    func testPDFKitViewDeep() {
        let pdf = makeTempPDF(pageCount: 3)
        defer { try? FileManager.default.removeItem(at: pdf) }
        deepRender(PDFKitView(url: pdf, currentPage: .constant(0), totalPages: .constant(3)), duration: 0.3)
    }

    func testScanReviewViewDeep() throws {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 140)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 140))
        }
        try deepRenderWithContext(ScanReviewView(scannedImages: [img, img]), duration: 0.3)
    }

    func testFileCategoryGridViewDeep() throws {
        var files: [DocumentFile] = []
        for i in 0..<5 {
            let ext = i % 2 == 0 ? "pdf" : "jpg"
            let file = DocumentFile(name: "File\(i)", fileExtension: ext, relativeFilePath: "File\(i).\(ext)", fileSize: Int64(i * 1024))
            files.append(file)
        }
        let vm = FilesViewModel()
        let view = FileCategoryGridView(files: files, selectedCategory: .constant(.all), viewModel: vm)
        try deepRenderWithContext(view, duration: 0.3)
    }

    func testFileListViewDeep() throws {
        var files: [DocumentFile] = []
        for i in 0..<5 {
            let file = DocumentFile(name: "File\(i)", fileExtension: "pdf", relativeFilePath: "File\(i).pdf", fileSize: Int64(i * 1024))
            files.append(file)
        }
        let view = FileListView(files: files, onSelect: { _ in }, onAction: { _, _ in })
        try deepRenderWithContext(view, duration: 0.3)
    }

    func testOnboardingViewDeep() {
        deepRender(OnboardingView(onComplete: {}), duration: 0.5)
    }

    func testWhatsNewViewDeep() {
        let features = [
            WhatsNewFeature(icon: "sparkles", iconColor: .blue, title: "AI Tools", description: "New AI tools suite"),
            WhatsNewFeature(icon: "signature", iconColor: .green, title: "Sign", description: "Sign documents"),
        ]
        deepRender(WhatsNewView(version: "1.1", features: features, onDismiss: {}), duration: 0.3)
    }
}

// MARK: - Chat View Component Deep Tests

@MainActor
final class DeepChatComponentTests: XCTestCase {

    func testChatBubbleUserDeep() {
        let conv = Conversation()
        let msg = ChatMessage(content: "Hello there, how do I merge PDFs?", role: "user", conversation: conv)
        deepRender(ChatBubbleView(message: msg, onAction: { _ in }))
    }

    func testChatBubbleAssistantDeep() {
        let conv = Conversation()
        let msg = ChatMessage(content: "You can use the Merge PDF tool. It allows you to combine multiple PDF files into one.", role: "assistant", conversation: conv, toolBadge: "Merge PDF")
        deepRender(ChatBubbleView(message: msg, onAction: { _ in }))
    }

    func testChatBubbleWithActionsDeep() {
        let actions = [
            ChatAction(label: "Open Scanner", icon: "doc.viewfinder", actionType: .openTool, toolId: "Scanner"),
            ChatAction(label: "Browse Tools", icon: "wrench", actionType: .navigateTab, tabId: "tools"),
        ]
        let conv = Conversation()
        let msg = ChatMessage(content: "Here are some options:", role: "assistant", conversation: conv, actions: actions)
        deepRender(ChatBubbleView(message: msg, onAction: { _ in }))
    }

    func testChatActionButtonsDeep() {
        let actions = [
            ChatAction(label: "Scan", icon: "doc.viewfinder", actionType: .openTool, toolId: "Scanner"),
            ChatAction(label: "Tools", icon: "wrench", actionType: .navigateTab, tabId: "tools"),
            ChatAction(label: "Files", icon: "folder", actionType: .navigateTab, tabId: "files"),
        ]
        deepRender(ChatActionButtonsView(actions: actions, onAction: { _ in }))
    }

    func testChatInputBarDeep() {
        deepRender(ChatInputBar(text: .constant("Hello"), isTyping: false, pendingAttachment: nil, isRecording: false, audioLevel: 0, onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}))
    }

    func testChatInputBarTypingDeep() {
        deepRender(ChatInputBar(text: .constant(""), isTyping: true, pendingAttachment: nil, isRecording: false, audioLevel: 0, onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}))
    }

    func testQuickActionsViewDeep() {
        let actions = [
            QuickAction(label: "Scan", icon: "doc.viewfinder", prompt: "Scan a doc"),
            QuickAction(label: "Merge", icon: "doc.on.doc.fill", prompt: "Merge PDFs"),
        ]
        deepRender(QuickActionsView(actions: actions, onTap: { _ in }))
    }

    func testChatHistoryViewDeep() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, configurations: config)

        var convs: [Conversation] = []
        for i in 0..<3 {
            let conv = Conversation()
            conv.title = "Chat \(i)"
            container.mainContext.insert(conv)
            convs.append(conv)
        }
        try container.mainContext.save()

        deepRender(
            ChatHistoryView(conversations: convs, onSelect: { _ in }, onDelete: { _ in })
                .modelContainer(container),
            duration: 0.3
        )
    }
}

// MARK: - File View Component Deep Tests

@MainActor
final class DeepFileComponentTests: XCTestCase {

    func testFileRowViewPDF() {
        let file = DocumentFile(name: "Report", fileExtension: "pdf", relativeFilePath: "Report.pdf", fileSize: 1024 * 512, pageCount: 10)
        deepRender(FileRowView(file: file, onAction: { _ in }))
    }

    func testFileRowViewImage() {
        let file = DocumentFile(name: "Photo", fileExtension: "jpg", relativeFilePath: "Photo.jpg", fileSize: 2048 * 1024)
        deepRender(FileRowView(file: file, onAction: { _ in }))
    }

    func testFileRowViewFavorite() {
        let file = DocumentFile(name: "Fav", fileExtension: "pdf", relativeFilePath: "Fav.pdf", fileSize: 1024)
        file.isFavorite = true
        deepRender(FileRowView(file: file, onAction: { _ in }))
    }

    func testFileActionsMenuDeep() {
        let file = DocumentFile(name: "Actions", fileExtension: "pdf", relativeFilePath: "Actions.pdf", fileSize: 1024)
        deepRender(FileActionsMenu(file: file, onAction: { _ in }))
    }

    func testFileRenameSheetDeep() {
        let file = DocumentFile(name: "TestFile", fileExtension: "pdf", relativeFilePath: "TestFile.pdf", fileSize: 1024)
        deepRender(FileRenameSheet(file: file, onRename: { _ in }))
    }

    func testFileDetailSheetDeep() {
        let file = DocumentFile(name: "Detail", fileExtension: "pdf", relativeFilePath: "Detail.pdf", fileSize: 1024 * 1024, pageCount: 25)
        deepRender(FileDetailSheet(file: file))
    }
}

// MARK: - Scanner Deep Tests

@MainActor
final class DeepScannerTests: XCTestCase {
    private func makeTestImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 140)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 140))
        }
    }

    func testScanActionBarDeep() {
        deepRender(ScanActionBar(
            onRotate: {},
            onDelete: {},
            onReorder: {},
            canDelete: true
        ))
    }

    func testScanActionBarCannotDelete() {
        deepRender(ScanActionBar(
            onRotate: {},
            onDelete: {},
            onReorder: {},
            canDelete: false
        ))
    }

    func testScanFilterBarDeep() {
        deepRender(ScanFilterBar(selectedFilter: .color, onFilterSelect: { _ in }))
    }

    func testScanFilterBarAllFilters() {
        for filter in ScanFilter.allCases {
            deepRender(ScanFilterBar(selectedFilter: filter, onFilterSelect: { _ in }))
        }
    }

    func testScanPagePreviewDeep() {
        let page = ScannedPage(image: makeTestImage())
        deepRender(ScanPagePreview(page: page))
    }

    func testScanPagePreviewNil() {
        deepRender(ScanPagePreview(page: nil))
    }

    func testScanPageStripViewDeep() {
        let pages = (0..<4).map { _ in ScannedPage(image: makeTestImage()) }
        deepRender(ScanPageStripView(
            pages: pages,
            selectedIndex: 1,
            onSelect: { _ in }
        ), duration: 0.3)
    }

    func testScanSaveSheetDeep() throws {
        let vm = ScanReviewViewModel()
        vm.pages = [ScannedPage(image: makeTestImage())]
        vm.fileName = "TestScan"
        try deepRenderWithContext(
            ScanSaveSheet(viewModel: vm, onSave: {}),
            duration: 0.3
        )
    }

    func testScanPageManagerSheetDeep() {
        let vm = ScanReviewViewModel()
        vm.pages = [ScannedPage(image: makeTestImage()), ScannedPage(image: makeTestImage()), ScannedPage(image: makeTestImage())]
        deepRender(
            ScanPageManagerSheet(viewModel: vm),
            duration: 0.3
        )
    }
}

// MARK: - AppTabView State Tests

@MainActor
final class DeepAppTabViewTests: XCTestCase {

    func testAppTabViewAllTabs() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, configurations: config)

        for tab in AppTab.allCases {
            let router = NavigationRouter()
            router.selectedTab = tab
            deepRender(
                AppTabView().environment(router).modelContainer(container),
                duration: 0.3
            )
        }
    }
}
