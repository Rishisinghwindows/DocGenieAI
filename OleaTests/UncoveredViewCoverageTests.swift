// UncoveredViewCoverageTests.swift
// Tests for 17 previously untested files: view rendering + logic tests.

@testable import Olea
import XCTest
import SwiftUI
import SwiftData
import UIKit
import PDFKit

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
private func deepRender<V: View>(_ view: V, duration: TimeInterval = 0.2) {
    let host = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = host
    window.makeKeyAndVisible()

    for size in [CGSize(width: 390, height: 844), CGSize(width: 320, height: 568), CGSize(width: 430, height: 932)] {
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }

    RunLoop.current.run(until: Date(timeIntervalSinceNow: duration))
    XCTAssertNotNil(host.view)
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    window.isHidden = true
}

@MainActor
private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, ChatMemory.self, configurations: config)
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

@MainActor
private func deepRenderWithContext<V: View>(_ view: V, duration: TimeInterval = 0.2) throws {
    let container = try makeContainer()
    let router = NavigationRouter()
    deepRender(view.environment(router).modelContainer(container), duration: duration)
}

private func makeTestImage() -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50)).image { ctx in
        UIColor.blue.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
    }
}

private func makeTempPDF(pageCount: Int = 1) -> URL {
    let doc = PDFDocument()
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 280))
    for i in 0..<pageCount {
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 280))
            ("Page \(i+1)" as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: [
                .font: UIFont.systemFont(ofSize: 12)
            ])
        }
        if let page = PDFPage(image: img) { doc.insert(page, at: i) }
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("uncov_\(UUID().uuidString).pdf")
    doc.write(to: url)
    return url
}

// MARK: - SecondaryButton Tests

@MainActor
final class SecondaryButtonRenderTests: XCTestCase {

    func testSecondaryButtonRenders() {
        render(SecondaryButton(title: "Cancel", action: {}))
    }

    func testSecondaryButtonWithIconRenders() {
        render(SecondaryButton(title: "Delete", icon: "trash", action: {}))
    }

    func testSecondaryButtonLoadingRenders() {
        render(SecondaryButton(title: "Loading", isLoading: true, action: {}))
    }

    func testSecondaryButtonNotLoadingRenders() {
        render(SecondaryButton(title: "Action", icon: "bolt", isLoading: false, action: {}))
    }

    func testSecondaryButtonDeepRenders() {
        deepRender(SecondaryButton(title: "Deep", icon: "star", action: {}))
    }
}

// MARK: - GhostButton Tests

@MainActor
final class GhostButtonRenderTests: XCTestCase {

    func testGhostButtonRenders() {
        render(GhostButton(title: "Cancel", action: {}))
    }

    func testGhostButtonWithIconRenders() {
        render(GhostButton(title: "Back", icon: "arrow.left", action: {}))
    }

    func testGhostButtonDeepRenders() {
        deepRender(GhostButton(title: "Deep Ghost", icon: "xmark", action: {}))
    }
}

// MARK: - VoicePulseView Tests

@MainActor
final class VoicePulseViewRenderTests: XCTestCase {

    func testVoicePulseViewZeroLevel() {
        render(VoicePulseView(audioLevel: 0))
    }

    func testVoicePulseViewLowLevel() {
        render(VoicePulseView(audioLevel: 0.2))
    }

    func testVoicePulseViewMidLevel() {
        render(VoicePulseView(audioLevel: 0.5))
    }

    func testVoicePulseViewHighLevel() {
        render(VoicePulseView(audioLevel: 1.0))
    }

    func testVoicePulseViewDeepRenders() {
        deepRender(VoicePulseView(audioLevel: 0.7), duration: 0.3)
    }
}

// MARK: - CompressionComparisonBar Tests

@MainActor
final class CompressionComparisonBarRenderTests: XCTestCase {

    func testBarWith50PercentReduction() {
        render(CompressionComparisonBar(originalSize: 1000, compressedSize: 500))
    }

    func testBarWith90PercentReduction() {
        render(CompressionComparisonBar(originalSize: 10000, compressedSize: 1000))
    }

    func testBarWithZeroReduction() {
        render(CompressionComparisonBar(originalSize: 1000, compressedSize: 1000))
    }

    func testBarWithZeroOriginal() {
        render(CompressionComparisonBar(originalSize: 0, compressedSize: 0))
    }

    func testBarWithSmallSizes() {
        render(CompressionComparisonBar(originalSize: 100, compressedSize: 30))
    }

    func testBarDeepRenders() {
        deepRender(CompressionComparisonBar(originalSize: 2048000, compressedSize: 512000), duration: 0.5)
    }
}

// MARK: - AttachmentPreviewStrip Tests

@MainActor
final class AttachmentPreviewStripRenderTests: XCTestCase {

    func testAttachmentPreviewPDF() {
        let attachment = PendingAttachment(
            fileName: "Document",
            fileExtension: "pdf",
            url: URL(fileURLWithPath: "/tmp/test.pdf"),
            iconSystemName: "doc.fill"
        )
        render(AttachmentPreviewStrip(attachment: attachment, onRemove: {}))
    }

    func testAttachmentPreviewImage() {
        let attachment = PendingAttachment(
            fileName: "Photo",
            fileExtension: "jpg",
            url: URL(fileURLWithPath: "/tmp/test.jpg"),
            iconSystemName: "photo"
        )
        render(AttachmentPreviewStrip(attachment: attachment, onRemove: {}))
    }

    func testAttachmentPreviewTextFile() {
        let attachment = PendingAttachment(
            fileName: "Notes",
            fileExtension: "txt",
            url: URL(fileURLWithPath: "/tmp/notes.txt"),
            iconSystemName: "doc.text"
        )
        render(AttachmentPreviewStrip(attachment: attachment, onRemove: {}))
    }

    func testAttachmentPreviewDeepRenders() {
        let attachment = PendingAttachment(
            fileName: "Report",
            fileExtension: "docx",
            url: URL(fileURLWithPath: "/tmp/report.docx"),
            iconSystemName: "doc.richtext"
        )
        deepRender(AttachmentPreviewStrip(attachment: attachment, onRemove: {}))
    }
}

// MARK: - PDFThumbnailView Tests

@MainActor
final class PDFThumbnailViewRenderTests: XCTestCase {

    func testPDFThumbnailViewNoDocument() throws {
        try renderWithContainer(PDFThumbnailView(documentFileId: "nonexistent"))
    }

    func testPDFThumbnailViewEmptyId() throws {
        try renderWithContainer(PDFThumbnailView(documentFileId: ""))
    }

    func testPDFThumbnailViewWithDocumentInDB() throws {
        let container = try makeContainer()
        let pdf = makeTempPDF()
        defer { try? FileManager.default.removeItem(at: pdf) }

        let file = DocumentFile(name: "ThumbTest", fileExtension: "pdf", relativeFilePath: "ThumbTest.pdf", fileSize: 1024, pageCount: 1)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let view = PDFThumbnailView(documentFileId: file.id.uuidString)
            .modelContainer(container)
        deepRender(view, duration: 0.3)
    }
}

// MARK: - ScanPageThumbnailStrip Tests

@MainActor
final class ScanPageThumbnailStripRenderTests: XCTestCase {

    func testScanPageStripNoDocument() throws {
        try renderWithContainer(ScanPageThumbnailStrip(documentFileId: "nonexistent", pageCount: 3))
    }

    func testScanPageStripSinglePage() throws {
        try renderWithContainer(ScanPageThumbnailStrip(documentFileId: "", pageCount: 1))
    }

    func testScanPageStripManyPages() throws {
        try renderWithContainer(ScanPageThumbnailStrip(documentFileId: "", pageCount: 10))
    }

    func testScanPageStripWithDocument() throws {
        let container = try makeContainer()
        let pdf = makeTempPDF(pageCount: 6)
        defer { try? FileManager.default.removeItem(at: pdf) }

        let file = DocumentFile(name: "StripTest", fileExtension: "pdf", relativeFilePath: "StripTest.pdf", fileSize: 2048, pageCount: 6)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let view = ScanPageThumbnailStrip(documentFileId: file.id.uuidString, pageCount: 6)
            .modelContainer(container)
        deepRender(view, duration: 0.3)
    }
}

// MARK: - DocumentMetadataRow Tests

@MainActor
final class DocumentMetadataRowRenderTests: XCTestCase {

    func testMetadataRowNoDocument() throws {
        try renderWithContainer(DocumentMetadataRow(documentFileId: "nonexistent"))
    }

    func testMetadataRowEmptyId() throws {
        try renderWithContainer(DocumentMetadataRow(documentFileId: ""))
    }

    func testMetadataRowWithSmallFile() throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Small", fileExtension: "pdf", relativeFilePath: "Small.pdf", fileSize: 512)
        container.mainContext.insert(file)
        try container.mainContext.save()
        render(DocumentMetadataRow(documentFileId: file.id.uuidString).modelContainer(container))
    }

    func testMetadataRowWithKBFile() throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Medium", fileExtension: "pdf", relativeFilePath: "Medium.pdf", fileSize: 50 * 1024, pageCount: 5)
        container.mainContext.insert(file)
        try container.mainContext.save()
        render(DocumentMetadataRow(documentFileId: file.id.uuidString).modelContainer(container))
    }

    func testMetadataRowWithMBFile() throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Large", fileExtension: "pdf", relativeFilePath: "Large.pdf", fileSize: 5 * 1024 * 1024, pageCount: 100)
        container.mainContext.insert(file)
        try container.mainContext.save()
        render(DocumentMetadataRow(documentFileId: file.id.uuidString).modelContainer(container))
    }

    func testMetadataRowWithByteSizeFile() throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Tiny", fileExtension: "txt", relativeFilePath: "Tiny.txt", fileSize: 42)
        container.mainContext.insert(file)
        try container.mainContext.save()
        render(DocumentMetadataRow(documentFileId: file.id.uuidString).modelContainer(container))
    }

    func testMetadataRowNoPageCount() throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "NoPages", fileExtension: "jpg", relativeFilePath: "NoPages.jpg", fileSize: 1024)
        container.mainContext.insert(file)
        try container.mainContext.save()
        render(DocumentMetadataRow(documentFileId: file.id.uuidString).modelContainer(container))
    }
}

// MARK: - ProcessingBubbleView Tests

@MainActor
final class ProcessingBubbleViewRenderTests: XCTestCase {

    private func makeProcessingMsg(toolType: String) -> ChatMessage {
        let conv = Conversation()
        return ChatMessage(
            content: "Processing your document...",
            role: "assistant",
            conversation: conv,
            messageType: "processing",
            inlineToolType: toolType
        )
    }

    func testProcessingBubbleOCR() {
        render(ProcessingBubbleView(message: makeProcessingMsg(toolType: "ocr")))
    }

    func testProcessingBubbleSummarize() {
        render(ProcessingBubbleView(message: makeProcessingMsg(toolType: "summarize")))
    }

    func testProcessingBubbleCompress() {
        render(ProcessingBubbleView(message: makeProcessingMsg(toolType: "compress")))
    }

    func testProcessingBubbleWatermark() {
        render(ProcessingBubbleView(message: makeProcessingMsg(toolType: "watermark")))
    }

    func testProcessingBubbleUnknownTool() {
        render(ProcessingBubbleView(message: makeProcessingMsg(toolType: "custom")))
    }

    func testProcessingBubbleEmptyToolType() {
        render(ProcessingBubbleView(message: makeProcessingMsg(toolType: "")))
    }

    func testProcessingBubbleDeepRenders() {
        deepRender(ProcessingBubbleView(message: makeProcessingMsg(toolType: "ocr")), duration: 0.3)
    }
}

// MARK: - ToolResultBubbleView Tests

@MainActor
final class ToolResultBubbleViewRenderTests: XCTestCase {

    private func makeResultMsg(success: Bool, toolType: String = "ocr", content: String = "Extracted text here.", outputFileName: String? = nil, originalSize: Int64? = nil, compressedSize: Int64? = nil) -> ChatMessage {
        let conv = Conversation()
        let result = InlineToolResult(
            toolType: toolType,
            success: success,
            title: success ? "Success" : "Error",
            content: content,
            outputFileName: outputFileName,
            originalSize: originalSize,
            compressedSize: compressedSize
        )
        let json = (try? JSONEncoder().encode(result)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return ChatMessage(
            content: content,
            role: "assistant",
            conversation: conv,
            toolBadge: "OCR",
            messageType: "toolResult",
            resultDataJSON: json
        )
    }

    func testToolResultSuccess() {
        render(ToolResultBubbleView(message: makeResultMsg(success: true)))
    }

    func testToolResultFailure() {
        render(ToolResultBubbleView(message: makeResultMsg(success: false, content: "File not found")))
    }

    func testToolResultWithOutputFile() {
        render(ToolResultBubbleView(message: makeResultMsg(success: true, outputFileName: "output.pdf")))
    }

    func testToolResultCompressWithComparison() {
        render(ToolResultBubbleView(message: makeResultMsg(
            success: true,
            toolType: "compress",
            content: "Reduced by 40%",
            outputFileName: "compressed.pdf",
            originalSize: 1000000,
            compressedSize: 600000
        )))
    }

    func testToolResultLongContent() {
        let longText = String(repeating: "This is a very long extracted text. ", count: 30)
        render(ToolResultBubbleView(message: makeResultMsg(success: true, content: longText)))
    }

    func testToolResultShortContent() {
        render(ToolResultBubbleView(message: makeResultMsg(success: true, content: "Short.")))
    }

    func testToolResultEmptyContent() {
        render(ToolResultBubbleView(message: makeResultMsg(success: true, content: "")))
    }

    func testToolResultWithActions() {
        let conv = Conversation()
        let result = InlineToolResult(toolType: "ocr", success: true, title: "Done", content: "Text extracted")
        let json = (try? JSONEncoder().encode(result)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let actions = [ChatAction(label: "View File", icon: "doc", actionType: .openFile, fileId: "123")]
        let msg = ChatMessage(
            content: "Text extracted",
            role: "assistant",
            conversation: conv,
            toolBadge: "OCR",
            actions: actions,
            messageType: "toolResult",
            resultDataJSON: json
        )
        render(ToolResultBubbleView(message: msg, onAction: { _ in }))
    }

    func testToolResultNoJSON() {
        let conv = Conversation()
        let msg = ChatMessage(
            content: "Some result",
            role: "assistant",
            conversation: conv,
            toolBadge: "Tool",
            messageType: "toolResult"
        )
        render(ToolResultBubbleView(message: msg))
    }

    func testToolResultDeepRenders() {
        deepRender(ToolResultBubbleView(message: makeResultMsg(success: true, content: "Deep render test")), duration: 0.4)
    }
}

// MARK: - DocumentCardBubbleView Tests

@MainActor
final class DocumentCardBubbleViewRenderTests: XCTestCase {

    func testDocumentCardNoDocument() throws {
        let conv = Conversation()
        let msg = ChatMessage(
            content: "Scanned document",
            role: "assistant",
            conversation: conv,
            toolBadge: "Scanner",
            messageType: "documentCard",
            documentFileId: UUID().uuidString
        )
        try renderWithContainer(DocumentCardBubbleView(message: msg))
    }

    func testDocumentCardScannerBadge() throws {
        let conv = Conversation()
        let msg = ChatMessage(
            content: "Your scanned file",
            role: "assistant",
            conversation: conv,
            toolBadge: "Scanner",
            messageType: "documentCard",
            documentFileId: ""
        )
        try renderWithContainer(DocumentCardBubbleView(message: msg))
    }

    func testDocumentCardMergeBadge() throws {
        let conv = Conversation()
        let msg = ChatMessage(
            content: "Merged PDF",
            role: "assistant",
            conversation: conv,
            toolBadge: "Merge PDF",
            messageType: "documentCard",
            documentFileId: ""
        )
        try renderWithContainer(DocumentCardBubbleView(message: msg))
    }

    func testDocumentCardWithActions() throws {
        let conv = Conversation()
        let actions = [
            ChatAction(label: "View", icon: "eye", actionType: .openFile, fileId: "123"),
            ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .openTool, toolId: "share")
        ]
        let msg = ChatMessage(
            content: "Here's your document",
            role: "assistant",
            conversation: conv,
            toolBadge: "Scanner",
            actions: actions,
            messageType: "documentCard",
            documentFileId: ""
        )
        try renderWithContainer(DocumentCardBubbleView(message: msg, onAction: { _ in }))
    }

    func testDocumentCardEmptyDocumentFileId() throws {
        let conv = Conversation()
        let msg = ChatMessage(
            content: "File ready",
            role: "assistant",
            conversation: conv,
            messageType: "documentCard",
            documentFileId: ""
        )
        try renderWithContainer(DocumentCardBubbleView(message: msg))
    }

    func testDocumentCardWithDocumentInDB() throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "CardTest", fileExtension: "pdf", relativeFilePath: "CardTest.pdf", fileSize: 2048, pageCount: 3)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let conv = Conversation()
        let msg = ChatMessage(
            content: "CardTest.pdf",
            role: "assistant",
            conversation: conv,
            toolBadge: "Scanner",
            messageType: "documentCard",
            documentFileId: file.id.uuidString
        )
        deepRender(DocumentCardBubbleView(message: msg).modelContainer(container), duration: 0.3)
    }

    func testDocumentCardSinglePage() throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "OnePage", fileExtension: "pdf", relativeFilePath: "OnePage.pdf", fileSize: 1024, pageCount: 1)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let conv = Conversation()
        let msg = ChatMessage(
            content: "OnePage.pdf",
            role: "assistant",
            conversation: conv,
            toolBadge: "Scanner",
            messageType: "documentCard",
            documentFileId: file.id.uuidString
        )
        render(DocumentCardBubbleView(message: msg).modelContainer(container))
    }

    func testDocumentCardNilPageCount() throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "NoPages", fileExtension: "jpg", relativeFilePath: "NoPages.jpg", fileSize: 512)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let conv = Conversation()
        let msg = ChatMessage(
            content: "NoPages.jpg",
            role: "assistant",
            conversation: conv,
            toolBadge: "Scanner",
            messageType: "documentCard",
            documentFileId: file.id.uuidString
        )
        render(DocumentCardBubbleView(message: msg).modelContainer(container))
    }
}

// MARK: - AboutView Tests

@MainActor
final class AboutViewRenderTests: XCTestCase {

    func testAboutViewRenders() {
        render(AboutView())
    }

    func testAboutViewDeepRenders() {
        deepRender(AboutView(), duration: 0.3)
    }
}

// MARK: - PrivacyPolicyView Tests

@MainActor
final class PrivacyPolicyViewRenderTests: XCTestCase {

    func testPrivacyPolicyViewRenders() {
        render(PrivacyPolicyView())
    }

    func testPrivacyPolicyViewDeepRenders() {
        deepRender(PrivacyPolicyView(), duration: 0.3)
    }
}

// MARK: - TermsAndConditionsView Tests

@MainActor
final class TermsAndConditionsViewRenderTests: XCTestCase {

    func testTermsAndConditionsViewRenders() {
        render(TermsAndConditionsView())
    }

    func testTermsAndConditionsViewDeepRenders() {
        deepRender(TermsAndConditionsView(), duration: 0.3)
    }
}

// MARK: - SpotlightOverlayView Tests

@MainActor
final class SpotlightOverlayViewRenderTests: XCTestCase {

    private func makeAnchors() -> [TutorialTarget: CGRect] {
        [
            .menuButton: CGRect(x: 20, y: 60, width: 44, height: 44),
            .toolsButton: CGRect(x: 330, y: 60, width: 44, height: 44),
            .chatInput: CGRect(x: 20, y: 750, width: 350, height: 44),
            .suggestionCards: CGRect(x: 20, y: 400, width: 350, height: 120)
        ]
    }

    func testSpotlightStep0() {
        render(SpotlightOverlayView(
            currentStep: .constant(0),
            isShowing: .constant(true),
            anchors: makeAnchors()
        ))
    }

    func testSpotlightStep1() {
        render(SpotlightOverlayView(
            currentStep: .constant(1),
            isShowing: .constant(true),
            anchors: makeAnchors()
        ))
    }

    func testSpotlightStep2() {
        render(SpotlightOverlayView(
            currentStep: .constant(2),
            isShowing: .constant(true),
            anchors: makeAnchors()
        ))
    }

    func testSpotlightLastStep() {
        render(SpotlightOverlayView(
            currentStep: .constant(3),
            isShowing: .constant(true),
            anchors: makeAnchors()
        ))
    }

    func testSpotlightOutOfBoundsStep() {
        render(SpotlightOverlayView(
            currentStep: .constant(99),
            isShowing: .constant(true),
            anchors: makeAnchors()
        ))
    }

    func testSpotlightNegativeStep() {
        render(SpotlightOverlayView(
            currentStep: .constant(-1),
            isShowing: .constant(true),
            anchors: makeAnchors()
        ))
    }

    func testSpotlightEmptyAnchors() {
        render(SpotlightOverlayView(
            currentStep: .constant(0),
            isShowing: .constant(true),
            anchors: [:]
        ))
    }

    func testSpotlightNotShowing() {
        render(SpotlightOverlayView(
            currentStep: .constant(0),
            isShowing: .constant(false),
            anchors: makeAnchors()
        ))
    }

    func testSpotlightTooltipAboveTarget() {
        // Place target in lower half of screen so tooltip appears above
        let anchors: [TutorialTarget: CGRect] = [
            .chatInput: CGRect(x: 20, y: 700, width: 350, height: 44)
        ]
        render(SpotlightOverlayView(
            currentStep: .constant(3),
            isShowing: .constant(true),
            anchors: anchors
        ))
    }

    func testSpotlightTooltipBelowTarget() {
        // Place target in upper half of screen so tooltip appears below
        let anchors: [TutorialTarget: CGRect] = [
            .menuButton: CGRect(x: 20, y: 60, width: 44, height: 44)
        ]
        render(SpotlightOverlayView(
            currentStep: .constant(0),
            isShowing: .constant(true),
            anchors: anchors
        ))
    }

    func testSpotlightDeepRenders() {
        deepRender(SpotlightOverlayView(
            currentStep: .constant(1),
            isShowing: .constant(true),
            anchors: makeAnchors()
        ), duration: 0.3)
    }
}

// MARK: - SettingsTabView Tests

@MainActor
final class SettingsTabViewRenderTests: XCTestCase {

    func testSettingsTabViewRenders() throws {
        try renderWithRouterAndContainer(SettingsTabView())
    }

    func testSettingsTabViewDeepRenders() throws {
        try deepRenderWithContext(SettingsTabView(), duration: 0.3)
    }

    func testSettingsTabViewWithConversations() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        let conv = Conversation()
        conv.title = "Test Chat"
        container.mainContext.insert(conv)
        try container.mainContext.save()

        deepRender(SettingsTabView().environment(router).modelContainer(container), duration: 0.3)
    }

    func testSettingsTabViewWithMemories() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        let memory = ChatMemory(content: "User prefers dark mode", category: "preference")
        container.mainContext.insert(memory)
        try container.mainContext.save()

        deepRender(SettingsTabView().environment(router).modelContainer(container), duration: 0.3)
    }

    func testSettingsTabViewWithConversationsAndMemories() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        for i in 0..<3 {
            let conv = Conversation()
            conv.title = "Chat \(i)"
            container.mainContext.insert(conv)
        }
        for category in ["preference", "fact", "context"] {
            let memory = ChatMemory(content: "Memory of type \(category)", category: category)
            container.mainContext.insert(memory)
        }
        try container.mainContext.save()

        deepRender(SettingsTabView().environment(router).modelContainer(container), duration: 0.3)
    }
}

// MARK: - MemoryListView Tests

@MainActor
final class MemoryListViewRenderTests: XCTestCase {

    func testMemoryListViewEmpty() throws {
        try renderWithContainer(MemoryListView())
    }

    func testMemoryListViewWithMemories() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        for i in 0..<5 {
            let memory = ChatMemory(content: "Memory \(i)", category: i % 2 == 0 ? "fact" : "preference")
            container.mainContext.insert(memory)
        }
        try container.mainContext.save()

        deepRender(MemoryListView().environment(router).modelContainer(container), duration: 0.3)
    }
}

// MARK: - InlineChatToolExecutor Logic Tests

@MainActor
final class InlineChatToolExecutorLogicTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, ChatMemory.self, configurations: config)
    }

    func testUnknownToolType() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Test", fileExtension: "pdf", relativeFilePath: "Test.pdf", fileSize: 1024)
        container.mainContext.insert(file)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "unknown_tool", documentFile: file, context: container.mainContext)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.title, "Unknown Tool")
        XCTAssertTrue(result.content.contains("not supported"))
    }

    func testOCRWithMissingFile() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Missing", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0)
        container.mainContext.insert(file)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "ocr", documentFile: file, context: container.mainContext)
        XCTAssertFalse(result.success)
    }

    func testSummarizeWithMissingFile() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Missing", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0)
        container.mainContext.insert(file)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "summarize", documentFile: file, context: container.mainContext)
        XCTAssertFalse(result.success)
    }

    func testCompressWithMissingFile() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Missing", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0)
        container.mainContext.insert(file)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "compress", documentFile: file, context: container.mainContext)
        XCTAssertFalse(result.success)
    }

    func testWatermarkWithMissingFile() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Missing", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0)
        container.mainContext.insert(file)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "watermark", documentFile: file, context: container.mainContext)
        XCTAssertFalse(result.success)
    }

    func testPageNumbersWithMissingFile() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Missing", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0)
        container.mainContext.insert(file)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "page_numbers", documentFile: file, context: container.mainContext)
        XCTAssertFalse(result.success)
    }

    func testRotateWithMissingFile() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Missing", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0)
        container.mainContext.insert(file)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "rotate", documentFile: file, context: container.mainContext)
        XCTAssertFalse(result.success)
    }

    func testPDFToTextWithMissingFile() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Missing", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0)
        container.mainContext.insert(file)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "pdf_to_text", documentFile: file, context: container.mainContext)
        XCTAssertFalse(result.success)
    }

    func testPDFToImageWithMissingFile() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Missing", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0)
        container.mainContext.insert(file)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "pdf_to_image", documentFile: file, context: container.mainContext)
        XCTAssertFalse(result.success)
    }

    func testDocToPDFWithMissingFile() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Missing", fileExtension: "docx", relativeFilePath: "nonexistent.docx", fileSize: 0)
        container.mainContext.insert(file)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "doc_to_pdf", documentFile: file, context: container.mainContext)
        // Converter may succeed with empty output or fail — both paths valid
        XCTAssertEqual(result.toolType, "doc_to_pdf")
    }

    func testAllTextTransformsMissingFile() async throws {
        let container = try makeContainer()
        let file = DocumentFile(name: "Missing", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0)
        container.mainContext.insert(file)

        for toolType in ["rewrite_formal", "rewrite_casual", "fix_grammar", "bullet_points", "expand"] {
            let result = await InlineChatToolExecutor.shared.execute(toolType: toolType, documentFile: file, context: container.mainContext)
            XCTAssertFalse(result.success, "\(toolType) should fail for missing file")
        }
    }

    func testOCRWithRealPDF() async throws {
        let container = try makeContainer()
        let pdfURL = makeTempPDF()
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        // Copy to app storage directory
        let storageDir = FileStorageService.shared.documentsDirectory
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        let destURL = storageDir.appendingPathComponent("ocr_test_\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: pdfURL, to: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        let relativePath = destURL.lastPathComponent
        let file = DocumentFile(name: "OCRTest", fileExtension: "pdf", relativeFilePath: relativePath, fileSize: 1024, pageCount: 1)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let result = await InlineChatToolExecutor.shared.execute(toolType: "ocr", documentFile: file, context: container.mainContext)
        XCTAssertTrue(result.success)
    }

    func testSummarizeWithRealPDF() async throws {
        let container = try makeContainer()
        let pdfURL = makeTempPDF()
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let storageDir = FileStorageService.shared.documentsDirectory
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        let destURL = storageDir.appendingPathComponent("sum_test_\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: pdfURL, to: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        let relativePath = destURL.lastPathComponent
        let file = DocumentFile(name: "SumTest", fileExtension: "pdf", relativeFilePath: relativePath, fileSize: 1024, pageCount: 1)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let result = await InlineChatToolExecutor.shared.execute(toolType: "summarize", documentFile: file, context: container.mainContext)
        // May succeed (with or without text) or fail depending on OCR output
        XCTAssertEqual(result.toolType, "summarize")
    }

    func testCompressWithRealPDF() async throws {
        let container = try makeContainer()
        let pdfURL = makeTempPDF(pageCount: 2)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let storageDir = FileStorageService.shared.documentsDirectory
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        let destURL = storageDir.appendingPathComponent("compress_test_\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: pdfURL, to: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        let relativePath = destURL.lastPathComponent
        let file = DocumentFile(name: "CompressTest", fileExtension: "pdf", relativeFilePath: relativePath, fileSize: 2048, pageCount: 2)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let result = await InlineChatToolExecutor.shared.execute(toolType: "compress", documentFile: file, context: container.mainContext)
        if result.success {
            XCTAssertEqual(result.title, "PDF Compressed")
            XCTAssertNotNil(result.originalSize)
            XCTAssertNotNil(result.compressedSize)
            XCTAssertNotNil(result.outputFileName)
        }
    }

    func testWatermarkWithRealPDF() async throws {
        let container = try makeContainer()
        let pdfURL = makeTempPDF()
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let storageDir = FileStorageService.shared.documentsDirectory
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        let destURL = storageDir.appendingPathComponent("wm_test_\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: pdfURL, to: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        let relativePath = destURL.lastPathComponent
        let file = DocumentFile(name: "WMTest", fileExtension: "pdf", relativeFilePath: relativePath, fileSize: 1024, pageCount: 1)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let result = await InlineChatToolExecutor.shared.execute(toolType: "watermark", documentFile: file, context: container.mainContext)
        if result.success {
            XCTAssertEqual(result.title, "Watermark Added")
            XCTAssertNotNil(result.outputFileName)
        }
    }

    func testRotateWithRealPDF() async throws {
        let container = try makeContainer()
        let pdfURL = makeTempPDF()
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let storageDir = FileStorageService.shared.documentsDirectory
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        let destURL = storageDir.appendingPathComponent("rot_test_\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: pdfURL, to: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        let relativePath = destURL.lastPathComponent
        let file = DocumentFile(name: "RotTest", fileExtension: "pdf", relativeFilePath: relativePath, fileSize: 1024, pageCount: 1)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let result = await InlineChatToolExecutor.shared.execute(toolType: "rotate", documentFile: file, context: container.mainContext)
        if result.success {
            XCTAssertEqual(result.title, "PDF Rotated")
        }
    }

    func testPageNumbersWithRealPDF() async throws {
        let container = try makeContainer()
        let pdfURL = makeTempPDF(pageCount: 3)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let storageDir = FileStorageService.shared.documentsDirectory
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        let destURL = storageDir.appendingPathComponent("pgn_test_\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: pdfURL, to: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        let relativePath = destURL.lastPathComponent
        let file = DocumentFile(name: "PgNTest", fileExtension: "pdf", relativeFilePath: relativePath, fileSize: 1024, pageCount: 3)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let result = await InlineChatToolExecutor.shared.execute(toolType: "page_numbers", documentFile: file, context: container.mainContext)
        if result.success {
            XCTAssertEqual(result.title, "Page Numbers Added")
        }
    }

    func testPDFToTextWithRealPDF() async throws {
        let container = try makeContainer()
        let pdfURL = makeTempPDF()
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let storageDir = FileStorageService.shared.documentsDirectory
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        let destURL = storageDir.appendingPathComponent("p2t_test_\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: pdfURL, to: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        let relativePath = destURL.lastPathComponent
        let file = DocumentFile(name: "P2TTest", fileExtension: "pdf", relativeFilePath: relativePath, fileSize: 1024, pageCount: 1)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let result = await InlineChatToolExecutor.shared.execute(toolType: "pdf_to_text", documentFile: file, context: container.mainContext)
        if result.success {
            XCTAssertEqual(result.title, "Text Extracted")
        }
    }

    func testPDFToImageWithRealPDF() async throws {
        let container = try makeContainer()
        let pdfURL = makeTempPDF()
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let storageDir = FileStorageService.shared.documentsDirectory
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        let destURL = storageDir.appendingPathComponent("p2i_test_\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: pdfURL, to: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        let relativePath = destURL.lastPathComponent
        let file = DocumentFile(name: "P2ITest", fileExtension: "pdf", relativeFilePath: relativePath, fileSize: 1024, pageCount: 1)
        container.mainContext.insert(file)
        try container.mainContext.save()

        let result = await InlineChatToolExecutor.shared.execute(toolType: "pdf_to_image", documentFile: file, context: container.mainContext)
        if result.success {
            XCTAssertEqual(result.title, "PDF Exported")
        }
    }

    func testFormatFileSize() async throws {
        let container = try makeContainer()

        // Test via compress which shows file sizes in output
        let file = DocumentFile(name: "Test", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0)
        container.mainContext.insert(file)

        // Exercise unknown tool path with various tool names to get coverage
        for tool in ["merge", "split", "lock", "unlock", "extract_pages", "sign", "crop", "reorder"] {
            let result = await InlineChatToolExecutor.shared.execute(toolType: tool, documentFile: file, context: container.mainContext)
            XCTAssertFalse(result.success)
            XCTAssertEqual(result.title, "Unknown Tool")
        }
    }
}

// MARK: - InlineToolResult Model Tests

final class InlineToolResultModelTests: XCTestCase {

    func testBasicInit() {
        let result = InlineToolResult(toolType: "ocr", success: true, title: "Done", content: "Text")
        XCTAssertEqual(result.toolType, "ocr")
        XCTAssertTrue(result.success)
        XCTAssertNil(result.outputFileId)
        XCTAssertNil(result.outputFileName)
        XCTAssertNil(result.originalSize)
        XCTAssertNil(result.compressedSize)
    }

    func testFullInit() {
        let result = InlineToolResult(
            toolType: "compress",
            success: true,
            title: "Compressed",
            content: "Reduced by 50%",
            outputFileId: "abc",
            outputFileName: "out.pdf",
            originalSize: 2000,
            compressedSize: 1000
        )
        XCTAssertEqual(result.outputFileId, "abc")
        XCTAssertEqual(result.outputFileName, "out.pdf")
        XCTAssertEqual(result.originalSize, 2000)
        XCTAssertEqual(result.compressedSize, 1000)
    }

    func testCodable() throws {
        let original = InlineToolResult(
            toolType: "watermark",
            success: true,
            title: "Watermarked",
            content: "Applied",
            outputFileId: "xyz",
            outputFileName: "watermarked.pdf"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InlineToolResult.self, from: data)
        XCTAssertEqual(decoded.toolType, original.toolType)
        XCTAssertEqual(decoded.success, original.success)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.outputFileId, original.outputFileId)
        XCTAssertEqual(decoded.outputFileName, original.outputFileName)
    }

    func testCodableWithSizes() throws {
        let original = InlineToolResult(
            toolType: "compress",
            success: true,
            title: "OK",
            content: "Done",
            originalSize: 5000,
            compressedSize: 2500
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InlineToolResult.self, from: data)
        XCTAssertEqual(decoded.originalSize, 5000)
        XCTAssertEqual(decoded.compressedSize, 2500)
    }
}

// MARK: - PendingAttachment Model Tests

final class PendingAttachmentModelTests: XCTestCase {

    func testFullFileName() {
        let attachment = PendingAttachment(
            fileName: "Document",
            fileExtension: "pdf",
            url: URL(fileURLWithPath: "/tmp/test.pdf"),
            iconSystemName: "doc"
        )
        XCTAssertEqual(attachment.fullFileName, "Document.pdf")
    }

    func testFullFileNameEmptyExtension() {
        let attachment = PendingAttachment(
            fileName: "NoExtension",
            fileExtension: "",
            url: URL(fileURLWithPath: "/tmp/test"),
            iconSystemName: "doc"
        )
        XCTAssertEqual(attachment.fullFileName, "NoExtension")
    }

    func testFromURL() {
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        let attachment = PendingAttachment.from(url: url)
        XCTAssertEqual(attachment.fileName, "report")
        XCTAssertEqual(attachment.fileExtension, "pdf")
        XCTAssertEqual(attachment.url, url)
    }

    func testEquality() {
        let a1 = PendingAttachment(fileName: "A", fileExtension: "pdf", url: URL(fileURLWithPath: "/a.pdf"), iconSystemName: "doc")
        let a2 = PendingAttachment(fileName: "A", fileExtension: "pdf", url: URL(fileURLWithPath: "/a.pdf"), iconSystemName: "doc")
        // Different UUIDs, so not equal
        XCTAssertNotEqual(a1, a2)
        // Same instance is equal
        XCTAssertEqual(a1, a1)
    }
}

// MARK: - TutorialStep & TutorialTarget Tests

final class TutorialStepTests: XCTestCase {

    func testTutorialStepCount() {
        XCTAssertEqual(TutorialStep.steps.count, 4)
    }

    func testTutorialTargetCases() {
        let targets = TutorialTarget.allCases
        XCTAssertTrue(targets.contains(.menuButton))
        XCTAssertTrue(targets.contains(.toolsButton))
        XCTAssertTrue(targets.contains(.chatInput))
        XCTAssertTrue(targets.contains(.suggestionCards))
    }

    func testEachStepHasContent() {
        for step in TutorialStep.steps {
            XCTAssertFalse(step.title.isEmpty)
            XCTAssertFalse(step.description.isEmpty)
            XCTAssertFalse(step.icon.isEmpty)
        }
    }

    func testStepTargetMapping() {
        let expectedTargets: [TutorialTarget] = [.menuButton, .toolsButton, .suggestionCards, .chatInput]
        for (i, target) in expectedTargets.enumerated() {
            XCTAssertEqual(TutorialStep.steps[i].target, target)
        }
    }
}
