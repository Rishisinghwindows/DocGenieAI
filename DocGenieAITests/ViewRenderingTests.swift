// ViewRenderingTests.swift
// UIHostingController-based view rendering tests for code coverage.
// Each test instantiates a SwiftUI view and triggers body evaluation.

@testable import DocGenieAI
import XCTest
import SwiftUI
import SwiftData
import UIKit
import PDFKit
import PencilKit

// MARK: - Helpers

@MainActor
private func render<V: View>(_ view: V) {
    let host = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    XCTAssertNotNil(host.view)
    window.isHidden = true
}

@MainActor
private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, configurations: config)
}

@MainActor
private func renderWithContainer<V: View>(_ view: V) throws {
    let container = try makeContainer()
    render(view.modelContainer(container))
}

@MainActor
private func renderWithRouterAndContainer<V: View>(_ view: V) throws {
    let container = try makeContainer()
    let router = NavigationRouter()
    render(view.environment(router).modelContainer(container))
}

private func makeTestImage() -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50)).image { ctx in
        UIColor.blue.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
    }
}

private func makeTempPDF() -> URL {
    let doc = PDFDocument()
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 140))
    let img = renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 140))
    }
    if let page = PDFPage(image: img) { doc.insert(page, at: 0) }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("render_test_\(UUID().uuidString).pdf")
    doc.write(to: url)
    return url
}

@MainActor
private func makeDocFile() -> DocumentFile {
    DocumentFile(name: "Test", fileExtension: "pdf", relativeFilePath: "Test.pdf", fileSize: 1024)
}

// MARK: - Design System Component Tests

@MainActor
final class ComponentRenderTests: XCTestCase {

    func testPrimaryButtonRenders() {
        render(PrimaryButton(title: "Test", action: {}))
    }

    func testPrimaryButtonWithIconRenders() {
        render(PrimaryButton(title: "Test", icon: "checkmark", action: {}))
    }

    func testPrimaryButtonLoadingRenders() {
        render(PrimaryButton(title: "Loading", isLoading: true, action: {}))
    }

    func testEmptyStateViewRenders() {
        render(EmptyStateView(icon: "doc", title: "No Files", message: "No files found"))
    }

    func testEmptyStateViewWithButtonRenders() {
        render(EmptyStateView(icon: "doc", title: "No Files", message: "No files", buttonTitle: "Import", action: {}))
    }

    func testGlowingIconRenders() {
        render(GlowingIcon(systemName: "star", color: .blue))
    }

    func testGlowingIconCustomSizeRenders() {
        render(GlowingIcon(systemName: "heart", color: .red, size: 32, bgSize: 56))
    }

    func testCategoryChipRenders() {
        render(CategoryChip(category: .all, count: 10, isSelected: false, action: {}))
    }

    func testCategoryChipSelectedRenders() {
        render(CategoryChip(category: .pdf, count: 5, isSelected: true, action: {}))
    }

    func testFileTypeIconPDFRenders() {
        render(FileTypeIcon(fileExtension: "pdf"))
    }

    func testFileTypeIconImageRenders() {
        render(FileTypeIcon(fileExtension: "jpg"))
    }

    func testFileTypeIconDocRenders() {
        render(FileTypeIcon(fileExtension: "docx"))
    }

    func testFileTypeIconSpreadsheetRenders() {
        render(FileTypeIcon(fileExtension: "xlsx"))
    }

    func testFileTypeIconUnknownRenders() {
        render(FileTypeIcon(fileExtension: "xyz"))
    }

    func testFileTypeIconCustomSizeRenders() {
        render(FileTypeIcon(fileExtension: "pdf", size: 48))
    }

    func testAnimatedCheckmarkRenders() {
        render(AnimatedCheckmark())
    }

    func testAnimatedCheckmarkCustomRenders() {
        render(AnimatedCheckmark(color: .red, size: 80))
    }

    func testTypingIndicatorRenders() {
        render(TypingIndicator())
    }

    func testSkeletonViewRenders() {
        render(SkeletonView())
    }

    func testSkeletonViewCustomRenders() {
        render(SkeletonView(width: 100, height: 20, cornerRadius: 8))
    }

    func testSkeletonRowRenders() {
        render(SkeletonRow())
    }

    func testSkeletonListRenders() {
        render(SkeletonList())
    }

    func testSkeletonListCustomCountRenders() {
        render(SkeletonList(count: 3))
    }

    func testConfettiViewRenders() {
        render(ConfettiView())
    }

    func testAppSearchBarRenders() {
        render(AppSearchBar(text: .constant("")))
    }

    func testAppSearchBarWithTextRenders() {
        render(AppSearchBar(text: .constant("hello"), placeholder: "Search..."))
    }

    func testSortMenuButtonRenders() {
        render(SortMenuButton(selectedSort: .constant(.dateDesc)))
    }

    func testAppCardSolidRenders() {
        render(AppCard(style: .solid) { Text("Hello") })
    }

    func testAppCardGlassRenders() {
        render(AppCard(style: .glass) { Text("Hello") })
    }

    func testScaleButtonStyleRenders() {
        render(Button("Test") {}.buttonStyle(.scale))
    }

    func testScaleButtonStyleCustomRenders() {
        render(Button("Test") {}.buttonStyle(.scale(0.9)))
    }

    func testConfettiModifierInactive() {
        render(Text("Test").confettiOnComplete(false))
    }

    func testConfettiModifierActive() {
        render(Text("Test").confettiOnComplete(true))
    }
}

// MARK: - Design System Theme Tests

@MainActor
final class ThemeViewRenderTests: XCTestCase {

    func testGlassCardModifierRenders() {
        render(Text("Test").glassCard())
    }

    func testGlassCardModifierCustomRadiusRenders() {
        render(Text("Test").glassCard(cornerRadius: 20))
    }

    func testGlowModifierRenders() {
        render(Text("Test").glow(color: .blue, radius: 10))
    }

    func testShimmerModifierRenders() {
        render(Text("Test").shimmer())
    }

    func testAnimatedGradientViewRenders() {
        render(AnimatedGradientView(colors: [.blue.opacity(0.1), .purple.opacity(0.1), .clear]))
    }

    func testStaggeredAppearModifierRenders() {
        render(Text("Test").staggeredAppear(index: 0))
    }

    func testStaggeredAppearModifierLargeIndexRenders() {
        render(Text("Test").staggeredAppear(index: 5))
    }
}

// MARK: - Scanner View Tests

@MainActor
final class ScannerViewRenderTests: XCTestCase {

    func testScanActionBarRenders() {
        render(ScanActionBar(onRotate: {}, onDelete: {}, onReorder: {}, canDelete: true))
    }

    func testScanActionBarCannotDeleteRenders() {
        render(ScanActionBar(onRotate: {}, onDelete: {}, onReorder: {}, canDelete: false))
    }

    func testScanFilterBarRenders() {
        render(ScanFilterBar(selectedFilter: .color, onFilterSelect: { _ in }))
    }

    func testScanFilterBarGrayscaleRenders() {
        render(ScanFilterBar(selectedFilter: .grayscale, onFilterSelect: { _ in }))
    }

    func testScanPagePreviewWithPageRenders() {
        let page = ScannedPage(image: makeTestImage())
        render(ScanPagePreview(page: page))
    }

    func testScanPagePreviewNilRenders() {
        render(ScanPagePreview(page: nil))
    }

    func testScanPageStripViewRenders() {
        let pages = [ScannedPage(image: makeTestImage()), ScannedPage(image: makeTestImage())]
        render(ScanPageStripView(pages: pages, selectedIndex: 0, onSelect: { _ in }))
    }

    func testScanSaveSheetRenders() {
        let vm = ScanReviewViewModel()
        vm.loadScannedImages([makeTestImage()])
        render(ScanSaveSheet(viewModel: vm, onSave: {}))
    }

    func testScanPageManagerSheetRenders() {
        let vm = ScanReviewViewModel()
        vm.loadScannedImages([makeTestImage(), makeTestImage()])
        render(ScanPageManagerSheet(viewModel: vm))
    }

    func testScanReviewViewRenders() throws {
        let container = try makeContainer()
        render(ScanReviewView(scannedImages: [makeTestImage()]).modelContainer(container))
    }
}

// MARK: - Chat View Tests

@MainActor
final class ChatViewRenderTests: XCTestCase {

    func testChatBubbleViewUserRenders() {
        let conv = Conversation()
        let msg = ChatMessage(content: "Hello", role: "user", conversation: conv)
        render(ChatBubbleView(message: msg))
    }

    func testChatBubbleViewAssistantRenders() {
        let conv = Conversation()
        let msg = ChatMessage(content: "Hi there!", role: "assistant", conversation: conv)
        render(ChatBubbleView(message: msg))
    }

    func testChatBubbleViewWithToolBadgeRenders() {
        let conv = Conversation()
        let msg = ChatMessage(content: "Test", role: "assistant", conversation: conv, toolBadge: "Merge")
        render(ChatBubbleView(message: msg))
    }

    func testChatBubbleViewWithActionsRenders() {
        let conv = Conversation()
        let action = ChatAction(label: "Open Merge", icon: "doc.on.doc", actionType: .openTool, toolId: "merge")
        let msg = ChatMessage(content: "Test", role: "assistant", conversation: conv, actions: [action])
        render(ChatBubbleView(message: msg, onAction: { _ in }))
    }

    func testChatInputBarRenders() {
        render(ChatInputBar(text: .constant(""), isTyping: false, pendingAttachment: nil, isRecording: false, audioLevel: 0, onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}))
    }

    func testChatInputBarWithTextRenders() {
        render(ChatInputBar(text: .constant("Hello"), isTyping: false, pendingAttachment: nil, isRecording: false, audioLevel: 0, onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}))
    }

    func testChatInputBarTypingRenders() {
        render(ChatInputBar(text: .constant(""), isTyping: true, pendingAttachment: nil, isRecording: false, audioLevel: 0, onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}))
    }

    func testQuickActionsViewRenders() {
        let actions = [
            QuickAction(label: "Scan", icon: "doc.viewfinder", prompt: "Scan a document"),
            QuickAction(label: "Merge", icon: "doc.on.doc", prompt: "Merge PDFs")
        ]
        render(QuickActionsView(actions: actions, onTap: { _ in }))
    }

    func testChatActionButtonsViewRenders() {
        let actions = [
            ChatAction(label: "Open Merge", icon: "doc.on.doc", actionType: .openTool, toolId: "merge"),
            ChatAction(label: "Files Tab", icon: "folder", actionType: .navigateTab, tabId: "files")
        ]
        render(ChatActionButtonsView(actions: actions, onAction: { _ in }))
    }

    func testChatHistoryViewEmptyRenders() {
        render(ChatHistoryView(conversations: [], onSelect: { _ in }, onDelete: { _ in }))
    }

    func testChatHistoryViewWithConversationsRenders() {
        let conv = Conversation(title: "Test Chat")
        render(ChatHistoryView(conversations: [conv], onSelect: { _ in }, onDelete: { _ in }))
    }
}

// MARK: - File View Tests

@MainActor
final class FileViewRenderTests: XCTestCase {

    func testFileRowViewRenders() {
        let file = makeDocFile()
        render(FileRowView(file: file, onAction: { _ in }))
    }

    func testFileRowViewFavoriteRenders() {
        let file = makeDocFile()
        file.isFavorite = true
        render(FileRowView(file: file, onAction: { _ in }))
    }

    func testFileActionsMenuRenders() {
        let file = makeDocFile()
        render(FileActionsMenu(file: file, onAction: { _ in }))
    }

    func testFileActionsMenuFavoriteRenders() {
        let file = makeDocFile()
        file.isFavorite = true
        render(FileActionsMenu(file: file, onAction: { _ in }))
    }

    func testFileListViewEmptyRenders() {
        render(FileListView(files: [], onSelect: { _ in }, onAction: { _, _ in }))
    }

    func testFileListViewWithFilesRenders() {
        let file = makeDocFile()
        render(FileListView(files: [file], onSelect: { _ in }, onAction: { _, _ in }))
    }

    func testFileRenameSheetRenders() {
        let file = makeDocFile()
        render(FileRenameSheet(file: file, onRename: { _ in }))
    }

    func testFileDetailSheetRenders() {
        let file = makeDocFile()
        render(FileDetailSheet(file: file))
    }

    func testFileDetailSheetWithDatesRenders() {
        let file = makeDocFile()
        file.originalCreatedAt = Date()
        file.originalModifiedAt = Date()
        file.lastOpenedAt = Date()
        file.pageCount = 5
        render(FileDetailSheet(file: file))
    }

    func testFileImportButtonRenders() throws {
        try renderWithContainer(FileImportButton())
    }

    func testFileCategoryGridViewRenders() throws {
        let container = try makeContainer()
        let vm = FilesViewModel()
        let view = FileCategoryGridView(
            files: [],
            selectedCategory: .constant(.all),
            viewModel: vm
        ).modelContainer(container)
        render(view)
    }
}

// MARK: - Viewer Tests

@MainActor
final class ViewerRenderTests: XCTestCase {

    func testImageViewerViewRenders() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_img_\(UUID().uuidString).png")
        if let data = makeTestImage().pngData() { try? data.write(to: url) }
        render(ImageViewerView(url: url, fileName: "test.png"))
        try? FileManager.default.removeItem(at: url)
    }

    func testImageViewerViewMissingFileRenders() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent_image.png")
        render(ImageViewerView(url: url, fileName: "missing.png"))
    }

    func testPDFViewerViewRenders() {
        let url = makeTempPDF()
        render(PDFViewerView(url: url, fileName: "test.pdf"))
        try? FileManager.default.removeItem(at: url)
    }

    func testQuickLookViewerViewRenders() {
        let url = makeTempPDF()
        render(QuickLookViewerView(url: url, fileName: "test.pdf"))
        try? FileManager.default.removeItem(at: url)
    }

    func testDocumentViewerRouterRenders() throws {
        let file = makeDocFile()
        try renderWithContainer(DocumentViewerRouter(file: file))
    }
}

// MARK: - PDF Tool View Tests

@MainActor
final class PDFToolViewRenderTests: XCTestCase {

    func testMergePDFViewRenders() throws {
        try renderWithContainer(MergePDFView())
    }

    func testSplitPDFViewRenders() throws {
        try renderWithContainer(SplitPDFView())
    }

    func testCompressPDFViewRenders() throws {
        try renderWithContainer(CompressPDFView())
    }

    func testWatermarkPDFViewRenders() throws {
        try renderWithContainer(WatermarkPDFView())
    }

    func testLockPDFViewRenders() throws {
        try renderWithContainer(LockPDFView())
    }

    func testUnlockPDFViewRenders() throws {
        try renderWithContainer(UnlockPDFView())
    }

    func testRotatePDFViewRenders() throws {
        try renderWithContainer(RotatePDFView())
    }

    func testSignPDFViewRenders() throws {
        try renderWithContainer(SignPDFView())
    }

    func testCropPDFViewRenders() throws {
        try renderWithContainer(CropPDFView())
    }

    func testExtractPagesPDFViewRenders() throws {
        try renderWithContainer(ExtractPagesPDFView())
    }

    func testReorderPDFViewRenders() throws {
        try renderWithContainer(ReorderPDFView())
    }

    func testPageNumbersPDFViewRenders() throws {
        try renderWithContainer(PageNumbersPDFView())
    }

    func testMetadataEditorViewRenders() throws {
        try renderWithContainer(MetadataEditorView())
    }

    func testOCRTextViewRenders() throws {
        try renderWithContainer(OCRTextView())
    }

    func testEmailPDFViewRenders() throws {
        try renderWithContainer(EmailPDFView())
    }

    func testPDFFilePickerViewRenders() throws {
        try renderWithContainer(
            PDFFilePickerView(
                title: "Select PDF",
                allowsMultiple: false,
                selectedFiles: .constant([])
            )
        )
    }
}

// MARK: - AI Tool View Tests

@MainActor
final class AIToolViewRenderTests: XCTestCase {

    func testSummarizePDFViewRenders() throws {
        try renderWithContainer(SummarizePDFView())
    }

    func testAskPDFViewRenders() throws {
        try renderWithContainer(AskPDFView())
    }

    func testTranslatePDFViewRenders() throws {
        try renderWithContainer(TranslatePDFView())
    }
}

// MARK: - Converter View Tests

@MainActor
final class ConverterViewRenderTests: XCTestCase {

    func testImageToPDFViewRenders() throws {
        try renderWithContainer(ImageToPDFView())
    }

    func testDocToPDFViewRenders() throws {
        try renderWithContainer(DocToPDFView())
    }

    func testPDFToImageViewRenders() throws {
        try renderWithContainer(PDFToImageView())
    }

    func testPDFToTextViewRenders() throws {
        try renderWithContainer(PDFToTextView())
    }
}

// MARK: - Tool Card Tests

@MainActor
final class ToolCardRenderTests: XCTestCase {

    func testToolCardViewAllTools() {
        for tool in ToolItem.allCases {
            render(ToolCardView(tool: tool, action: {}))
        }
    }
}

// MARK: - Tab & Full Screen View Tests

@MainActor
final class TabViewRenderTests: XCTestCase {

    func testTransferTabPlaceholderRenders() {
        render(TransferTabPlaceholder())
    }

    func testOnboardingViewRenders() {
        render(OnboardingView(onComplete: {}))
    }

    func testWhatsNewViewRenders() {
        let features = [
            WhatsNewFeature(
                icon: "brain",
                iconColor: .purple,
                title: "AI Tools",
                description: "New AI tools"
            )
        ]
        render(WhatsNewView(version: "1.1", features: features, onDismiss: {}))
    }

    func testToolsTabViewRenders() throws {
        try renderWithRouterAndContainer(ToolsTabView())
    }

    func testChatTabViewRenders() throws {
        try renderWithRouterAndContainer(ChatTabView())
    }

    func testFilesTabViewRenders() throws {
        try renderWithRouterAndContainer(FilesTabView())
    }
}

// MARK: - UIViewRepresentable Tests

@MainActor
final class RepresentableRenderTests: XCTestCase {

    func testSignatureCanvasViewRenders() {
        render(SignatureCanvasView(drawing: .constant(PKDrawing())))
    }

    func testPDFKitViewRenders() {
        let url = makeTempPDF()
        render(PDFKitView(url: url, currentPage: .constant(1), totalPages: .constant(1)))
        try? FileManager.default.removeItem(at: url)
    }

    func testDocumentPickerViewRenders() {
        render(DocumentPickerView(onPick: { _ in }))
    }
}

// MARK: - FlowLayout Tests

@MainActor
final class FlowLayoutRenderTests: XCTestCase {

    func testFlowLayoutRendersWithMultipleChildren() {
        let view = FlowLayout(spacing: 8) {
            Text("Tag 1")
            Text("Tag 2")
            Text("Tag 3")
        }
        render(view)
    }
}

// MARK: - AppTabView Tests

@MainActor
final class AppTabViewRenderTests: XCTestCase {

    func testAppTabViewRenders() throws {
        let container = try makeContainer()
        render(AppTabView().modelContainer(container))
    }
}

// MARK: - Extra Coverage: View Modifiers and Extensions

@MainActor
final class ViewModifierCoverageTests: XCTestCase {

    func testAllCategoryChips() {
        for cat in FileCategory.allCases {
            render(CategoryChip(category: cat, count: 1, isSelected: false, action: {}))
            render(CategoryChip(category: cat, count: 0, isSelected: true, action: {}))
        }
    }

    func testAllFileTypeIcons() {
        let extensions = ["pdf", "jpg", "jpeg", "png", "heic", "doc", "docx", "xls", "xlsx",
                          "ppt", "pptx", "txt", "csv", "rtf", "xml", "mp3", "mp4", "zip", "unknown"]
        for ext in extensions {
            render(FileTypeIcon(fileExtension: ext))
        }
    }

    func testAllScanFilters() {
        for filter in ScanFilter.allCases {
            render(ScanFilterBar(selectedFilter: filter, onFilterSelect: { _ in }))
        }
    }

    func testAllSortOptions() {
        for option in FileSortOption.allCases {
            render(SortMenuButton(selectedSort: .constant(option)))
        }
    }

    func testEmptyStateVariations() {
        render(EmptyStateView(icon: "clock.arrow.circlepath", title: "No Conversations", message: "Start a chat."))
        render(EmptyStateView(icon: "doc.on.doc", title: "No Files Yet", message: "Import documents."))
        render(EmptyStateView(icon: "doc.richtext", title: "No PDFs", message: "Import PDFs first."))
        render(EmptyStateView(icon: "photo", title: "No Images", message: "Import images."))
    }

    func testAppCardVariations() {
        render(AppCard(style: .solid) { Text("Solid content") })
        render(AppCard(style: .glass) { Text("Glass content") })
        render(AppCard { Text("Default style") })
    }

    func testMultipleGlowingIcons() {
        let icons = [("star.fill", Color.yellow), ("heart.fill", Color.red), ("bolt.fill", Color.orange)]
        for (name, color) in icons {
            render(GlowingIcon(systemName: name, color: color, size: 20, bgSize: 40))
        }
    }
}

// MARK: - Representable Coordinator Tests

@MainActor
final class CoordinatorTests: XCTestCase {

    func testSignatureCanvasCoordinator() {
        let canvas = SignatureCanvasView(drawing: .constant(PKDrawing()))
        let coordinator = canvas.makeCoordinator()
        XCTAssertNotNil(coordinator)
    }

    func testPDFKitViewCoordinator() {
        let url = makeTempPDF()
        let pdfKitView = PDFKitView(url: url, currentPage: .constant(1), totalPages: .constant(1))
        let coordinator = pdfKitView.makeCoordinator()
        XCTAssertNotNil(coordinator)
        try? FileManager.default.removeItem(at: url)
    }

    func testDocumentPickerCoordinator() {
        let picker = DocumentPickerView(onPick: { _ in })
        let coordinator = picker.makeCoordinator()
        XCTAssertNotNil(coordinator)
    }
}
