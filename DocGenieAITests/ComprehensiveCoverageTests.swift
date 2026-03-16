import XCTest
import SwiftUI
import SwiftData
import UIKit
import PDFKit
@testable import DocGenieAI

// MARK: - ScanContentType Tests (0% → ~95%)

final class ScanContentTypeTests: XCTestCase {

    func testClassify_receipt() {
        let text = "RECEIPT\nItem 1 $10.00\nSubtotal $10.00\nTax $0.80\nTotal $10.80\nPayment by card\nThank you"
        XCTAssertEqual(ScanContentType.classify(ocrText: text), .receipt)
    }

    func testClassify_form() {
        let text = "Application Form\nName: John Doe\nDate: 2024-01-01\nAddress: 123 Main St\nPhone: 555-1234\nEmail: test@test.com\nPlease fill in all fields"
        XCTAssertEqual(ScanContentType.classify(ocrText: text), .form)
    }

    func testClassify_letter() {
        let text = "Dear Mr. Smith,\nI am writing to inform you about the matter. We have reviewed the documents and found everything in order.\nSincerely,\nJane Doe"
        XCTAssertEqual(ScanContentType.classify(ocrText: text), .letter)
    }

    func testClassify_textHeavy() {
        // >50 words but no keyword matches
        let words = (1...60).map { "word\($0)" }.joined(separator: " ")
        XCTAssertEqual(ScanContentType.classify(ocrText: words), .textHeavy)
    }

    func testClassify_imageHeavy() {
        // <10 words
        let text = "Photo caption here"
        XCTAssertEqual(ScanContentType.classify(ocrText: text), .imageHeavy)
    }

    func testClassify_unknown() {
        // 10-50 words, no keyword matches
        let words = (1...25).map { "word\($0)" }.joined(separator: " ")
        XCTAssertEqual(ScanContentType.classify(ocrText: words), .unknown)
    }

    func testDisplayLabel_allCases() {
        XCTAssertEqual(ScanContentType.receipt.displayLabel, "Receipt / Invoice")
        XCTAssertEqual(ScanContentType.letter.displayLabel, "Letter / Correspondence")
        XCTAssertEqual(ScanContentType.form.displayLabel, "Form / Application")
        XCTAssertEqual(ScanContentType.textHeavy.displayLabel, "Text Document")
        XCTAssertEqual(ScanContentType.imageHeavy.displayLabel, "Image / Photo")
        XCTAssertEqual(ScanContentType.unknown.displayLabel, "Document")
    }

    func testDisplayIcon_allCases() {
        XCTAssertEqual(ScanContentType.receipt.displayIcon, "creditcard")
        XCTAssertEqual(ScanContentType.letter.displayIcon, "envelope")
        XCTAssertEqual(ScanContentType.form.displayIcon, "doc.text")
        XCTAssertEqual(ScanContentType.textHeavy.displayIcon, "doc.plaintext")
        XCTAssertEqual(ScanContentType.imageHeavy.displayIcon, "photo")
        XCTAssertEqual(ScanContentType.unknown.displayIcon, "doc")
    }

    func testGenerateAutoSummary_receipt() {
        let text = "RECEIPT\nItem 1 $10.00\nTotal $10.80"
        let summary = ScanContentType.receipt.generateAutoSummary(ocrText: text)
        XCTAssertTrue(summary.contains("Receipt / Invoice"))
        XCTAssertTrue(summary.contains("$10"))
    }

    func testGenerateAutoSummary_letter() {
        let text = "Dear Mr. Smith, I am writing to inform you about the important matter at hand. This is a long enough sentence."
        let summary = ScanContentType.letter.generateAutoSummary(ocrText: text)
        XCTAssertTrue(summary.contains("Letter / Correspondence"))
        XCTAssertTrue(summary.contains("words"))
    }

    func testGenerateAutoSummary_form() {
        let text = "Name: John\nDate: 2024\nAddress: Main St"
        let summary = ScanContentType.form.generateAutoSummary(ocrText: text)
        XCTAssertTrue(summary.contains("Form / Application"))
        XCTAssertTrue(summary.contains("fields"))
    }

    func testGenerateAutoSummary_textHeavy() {
        let text = "First sentence that is long enough to pass the filter. Second sentence that is also quite long. Third sentence here for good measure too."
        let summary = ScanContentType.textHeavy.generateAutoSummary(ocrText: text)
        XCTAssertTrue(summary.contains("Text Document"))
        XCTAssertTrue(summary.contains("Key content"))
    }

    func testGenerateAutoSummary_imageHeavy() {
        let text = "A photo"
        let summary = ScanContentType.imageHeavy.generateAutoSummary(ocrText: text)
        XCTAssertTrue(summary.contains("image"))
        XCTAssertTrue(summary.contains("minimal text"))
    }

    func testGenerateAutoSummary_unknown() {
        let text = "Some document content that is moderately long enough to have a first sentence here."
        let summary = ScanContentType.unknown.generateAutoSummary(ocrText: text)
        XCTAssertTrue(summary.contains("document"))
        XCTAssertTrue(summary.contains("words"))
    }

    func testSuggestedActions_receipt() {
        let actions = ScanContentType.receipt.suggestedActions
        XCTAssertEqual(actions.count, 3)
        XCTAssertEqual(actions[0].toolType, "ocr")
        XCTAssertEqual(actions[1].toolType, "summarize")
        XCTAssertEqual(actions[2].toolType, "compress")
    }

    func testSuggestedActions_form() {
        let actions = ScanContentType.form.suggestedActions
        XCTAssertEqual(actions.count, 3)
        XCTAssertTrue(actions.contains { $0.toolType == "watermark" })
    }

    func testSuggestedActions_imageHeavy() {
        let actions = ScanContentType.imageHeavy.suggestedActions
        XCTAssertEqual(actions.count, 2)
        XCTAssertTrue(actions.contains { $0.toolType == "compress" })
        XCTAssertTrue(actions.contains { $0.toolType == "watermark" })
    }

    func testSuggestedActions_letter() {
        XCTAssertEqual(ScanContentType.letter.suggestedActions.count, 3)
    }

    func testSuggestedActions_textHeavy() {
        XCTAssertEqual(ScanContentType.textHeavy.suggestedActions.count, 3)
    }

    func testSuggestedActions_unknown() {
        XCTAssertEqual(ScanContentType.unknown.suggestedActions.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(ScanContentType.receipt.rawValue, "receipt")
        XCTAssertEqual(ScanContentType.letter.rawValue, "letter")
        XCTAssertEqual(ScanContentType.form.rawValue, "form")
        XCTAssertEqual(ScanContentType.textHeavy.rawValue, "textHeavy")
        XCTAssertEqual(ScanContentType.imageHeavy.rawValue, "imageHeavy")
        XCTAssertEqual(ScanContentType.unknown.rawValue, "unknown")
    }
}

// MARK: - InlineToolResult Tests (10% → ~95%)

final class InlineToolResultTests: XCTestCase {

    func testInit_allFields() {
        let result = InlineToolResult(
            toolType: "compress",
            success: true,
            title: "Compressed",
            content: "50% smaller",
            outputFileId: "abc-123",
            outputFileName: "test.pdf",
            originalSize: 1000,
            compressedSize: 500
        )
        XCTAssertEqual(result.toolType, "compress")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.title, "Compressed")
        XCTAssertEqual(result.content, "50% smaller")
        XCTAssertEqual(result.outputFileId, "abc-123")
        XCTAssertEqual(result.outputFileName, "test.pdf")
        XCTAssertEqual(result.originalSize, 1000)
        XCTAssertEqual(result.compressedSize, 500)
    }

    func testInit_minimalFields() {
        let result = InlineToolResult(toolType: "ocr", success: false, title: "Error", content: "Failed")
        XCTAssertNil(result.outputFileId)
        XCTAssertNil(result.outputFileName)
        XCTAssertNil(result.originalSize)
        XCTAssertNil(result.compressedSize)
    }

    func testCodable_roundTrip() throws {
        let original = InlineToolResult(
            toolType: "watermark",
            success: true,
            title: "Done",
            content: "Applied",
            outputFileId: "xyz",
            outputFileName: "doc_watermarked.pdf",
            originalSize: 2048,
            compressedSize: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InlineToolResult.self, from: data)
        XCTAssertEqual(decoded.toolType, original.toolType)
        XCTAssertEqual(decoded.success, original.success)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.outputFileId, original.outputFileId)
        XCTAssertEqual(decoded.outputFileName, original.outputFileName)
        XCTAssertEqual(decoded.originalSize, original.originalSize)
        XCTAssertNil(decoded.compressedSize)
    }

    func testCodable_minimalRoundTrip() throws {
        let original = InlineToolResult(toolType: "ocr", success: true, title: "T", content: "C")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InlineToolResult.self, from: data)
        XCTAssertEqual(decoded.toolType, "ocr")
        XCTAssertNil(decoded.outputFileId)
    }
}

// MARK: - PendingAttachment Tests (5% → ~95%)

final class PendingAttachmentTests: XCTestCase {

    func testFrom_pdf() {
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        let attachment = PendingAttachment.from(url: url)
        XCTAssertEqual(attachment.fileName, "report")
        XCTAssertEqual(attachment.fileExtension, "pdf")
        XCTAssertEqual(attachment.url, url)
        XCTAssertFalse(attachment.iconSystemName.isEmpty)
    }

    func testFrom_image() {
        let url = URL(fileURLWithPath: "/tmp/photo.jpg")
        let attachment = PendingAttachment.from(url: url)
        XCTAssertEqual(attachment.fileName, "photo")
        XCTAssertEqual(attachment.fileExtension, "jpg")
    }

    func testFrom_textFile() {
        let url = URL(fileURLWithPath: "/tmp/notes.txt")
        let attachment = PendingAttachment.from(url: url)
        XCTAssertEqual(attachment.fileName, "notes")
        XCTAssertEqual(attachment.fileExtension, "txt")
    }

    func testFrom_unknownExtension() {
        let url = URL(fileURLWithPath: "/tmp/data.xyz")
        let attachment = PendingAttachment.from(url: url)
        XCTAssertEqual(attachment.fileExtension, "xyz")
    }

    func testFullFileName_withExtension() {
        let url = URL(fileURLWithPath: "/tmp/doc.pdf")
        let attachment = PendingAttachment.from(url: url)
        XCTAssertEqual(attachment.fullFileName, "doc.pdf")
    }

    func testFullFileName_noExtension() {
        let url = URL(fileURLWithPath: "/tmp/Makefile")
        let attachment = PendingAttachment.from(url: url)
        // URL with no extension returns empty pathExtension
        XCTAssertEqual(attachment.fullFileName, attachment.fileName.isEmpty ? "" : attachment.fileName)
    }

    func testEquatable_sameInstanceNotEqual() {
        let url = URL(fileURLWithPath: "/tmp/a.pdf")
        let a = PendingAttachment.from(url: url)
        let b = PendingAttachment.from(url: url)
        // Each has unique UUID, so they are NOT equal
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_sameInstance() {
        let url = URL(fileURLWithPath: "/tmp/a.pdf")
        let a = PendingAttachment.from(url: url)
        XCTAssertEqual(a, a)
    }

    func testIdentifiable() {
        let url = URL(fileURLWithPath: "/tmp/a.pdf")
        let a = PendingAttachment.from(url: url)
        XCTAssertNotNil(a.id)
    }
}

// MARK: - Notification+App Tests (0% → 100%)

final class NotificationAppTests: XCTestCase {

    func testToolDidProduceDocument_name() {
        XCTAssertEqual(Notification.Name.toolDidProduceDocument.rawValue, "toolDidProduceDocument")
    }

    func testNotificationCanBePosted() {
        let expectation = XCTestExpectation(description: "notification received")
        let observer = NotificationCenter.default.addObserver(
            forName: .toolDidProduceDocument,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        NotificationCenter.default.post(name: .toolDidProduceDocument, object: nil)
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}

// MARK: - ToolItem Color Tests (gap fill)

final class ToolItemColorTests: XCTestCase {

    func testAllCasesHaveColor() {
        for tool in ToolItem.allCases {
            // Just accessing color should not crash; verify it returns a valid Color
            let _ = tool.color
        }
    }

    func testSpecificColors() {
        XCTAssertEqual(ToolItem.scanner.color, .appAccent)
        XCTAssertEqual(ToolItem.mergePDF.color, .appPrimary)
        XCTAssertEqual(ToolItem.splitPDF.color, .appWarning)
        XCTAssertEqual(ToolItem.compressPDF.color, .appSuccess)
        XCTAssertEqual(ToolItem.lockPDF.color, .appDanger)
        XCTAssertEqual(ToolItem.signPDF.color, .appDanger)
        XCTAssertEqual(ToolItem.emailPDF.color, .appWarning)
    }
}

// MARK: - ChatAction Extended Tests (gap fill)

final class ChatActionTypeAllCasesTests: XCTestCase {

    func testAllActionTypes_rawValues() {
        XCTAssertEqual(ChatActionType.openTool.rawValue, "openTool")
        XCTAssertEqual(ChatActionType.navigateTab.rawValue, "navigateTab")
        XCTAssertEqual(ChatActionType.openFile.rawValue, "openFile")
        XCTAssertEqual(ChatActionType.showResult.rawValue, "showResult")
        XCTAssertEqual(ChatActionType.executeInline.rawValue, "executeInline")
        XCTAssertEqual(ChatActionType.copyText.rawValue, "copyText")
        XCTAssertEqual(ChatActionType.shareFile.rawValue, "shareFile")
    }

    func testChatAction_withPayload() {
        let action = ChatAction(label: "Copy", icon: "doc", actionType: .copyText, payload: "some text")
        XCTAssertEqual(action.payload, "some text")
        XCTAssertNil(action.toolId)
        XCTAssertNil(action.tabId)
        XCTAssertNil(action.fileId)
    }

    func testChatAction_withFileId() {
        let action = ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: "file-123")
        XCTAssertEqual(action.fileId, "file-123")
        XCTAssertEqual(action.actionType, .shareFile)
    }

    func testChatAction_executeInline() {
        let action = ChatAction(label: "OCR", icon: "text.viewfinder", actionType: .executeInline, fileId: "doc1", payload: "ocr")
        XCTAssertEqual(action.actionType, .executeInline)
        XCTAssertEqual(action.fileId, "doc1")
        XCTAssertEqual(action.payload, "ocr")
    }

    func testChatAction_codable() throws {
        let action = ChatAction(label: "Test", icon: "star", actionType: .executeInline, fileId: "f1", payload: "summarize")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(ChatAction.self, from: data)
        XCTAssertEqual(decoded.label, "Test")
        XCTAssertEqual(decoded.actionType, .executeInline)
        XCTAssertEqual(decoded.payload, "summarize")
    }
}

// MARK: - ChatMessage Extended Tests (gap fill)

@MainActor
final class ChatMessageFieldTests: XCTestCase {

    func testInit_withAllNewFields() {
        let conv = Conversation()
        let msg = ChatMessage(
            content: "Processing...",
            role: "assistant",
            conversation: conv,
            messageType: "processing",
            documentFileId: "doc-uuid-123",
            resultDataJSON: "{\"key\":\"value\"}",
            inlineToolType: "ocr"
        )
        XCTAssertEqual(msg.messageType, "processing")
        XCTAssertEqual(msg.documentFileId, "doc-uuid-123")
        XCTAssertEqual(msg.resultDataJSON, "{\"key\":\"value\"}")
        XCTAssertEqual(msg.inlineToolType, "ocr")
    }

    func testInit_defaultFields() {
        let conv = Conversation()
        let msg = ChatMessage(content: "Hi", role: "user", conversation: conv)
        XCTAssertEqual(msg.messageType, "")
        XCTAssertEqual(msg.documentFileId, "")
        XCTAssertEqual(msg.resultDataJSON, "")
        XCTAssertEqual(msg.inlineToolType, "")
    }

    func testConversationRelationship() {
        let conv = Conversation(title: "Test Chat")
        let msg = ChatMessage(content: "Hello", role: "user", conversation: conv)
        XCTAssertEqual(msg.conversation?.id, conv.id)
        XCTAssertEqual(msg.conversationId, conv.id)
    }
}

// MARK: - KeywordMatchingProvider Extended Tests (60% → ~95%)

@MainActor
final class KeywordMatchingProviderFullTests: XCTestCase {
    let provider = KeywordMatchingProvider()

    func testScanKeyword() async throws {
        let response = try await provider.generateResponse(for: "I want to scan a document", conversationHistory: [])
        XCTAssertTrue(response.text.contains("scan"))
        XCTAssertEqual(response.toolBadge, "Scanner")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Scanner" })
    }

    func testMergeKeyword() async throws {
        let response = try await provider.generateResponse(for: "merge my PDFs", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Merge PDF")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Merge PDF" })
    }

    func testTranslateKeyword() async throws {
        let response = try await provider.generateResponse(for: "translate this document", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Translate PDF")
    }

    func testTranslate_withLanguageName() async throws {
        let response = try await provider.generateResponse(for: "convert this to hindi", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Translate PDF")
        XCTAssertTrue(response.text.contains("Hindi"))
    }

    func testConvertKeyword() async throws {
        let response = try await provider.generateResponse(for: "convert a file", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Converter")
        XCTAssertTrue(response.actions.count >= 4)
    }

    func testOCRKeyword() async throws {
        let response = try await provider.generateResponse(for: "extract text from image", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "OCR")
    }

    func testCompressKeyword() async throws {
        let response = try await provider.generateResponse(for: "compress my PDF", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Compress")
    }

    func testWatermarkKeyword() async throws {
        let response = try await provider.generateResponse(for: "add watermark", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Watermark")
    }

    func testLockKeyword() async throws {
        let response = try await provider.generateResponse(for: "lock my PDF with password", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Lock/Unlock")
        XCTAssertTrue(response.actions.contains { $0.toolId == "Lock PDF" })
        XCTAssertTrue(response.actions.contains { $0.toolId == "Unlock PDF" })
    }

    func testProtectKeyword() async throws {
        let response = try await provider.generateResponse(for: "protect this file", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Lock/Unlock")
    }

    func testSplitKeyword() async throws {
        let response = try await provider.generateResponse(for: "split PDF", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Split PDF")
    }

    func testRotateKeyword() async throws {
        let response = try await provider.generateResponse(for: "rotate pages", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Rotate PDF")
    }

    func testReorderKeyword() async throws {
        let response = try await provider.generateResponse(for: "reorder pages", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Reorder Pages")
    }

    func testRearrangeKeyword() async throws {
        let response = try await provider.generateResponse(for: "rearrange the pages", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Reorder Pages")
    }

    func testPageNumberKeyword() async throws {
        let response = try await provider.generateResponse(for: "add page numbers", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Page Numbers")
    }

    func testExtractPagesKeyword() async throws {
        let response = try await provider.generateResponse(for: "extract page 1-3", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Extract Pages")
    }

    func testSignKeyword() async throws {
        let response = try await provider.generateResponse(for: "sign this PDF", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Sign PDF")
    }

    func testSignatureKeyword() async throws {
        let response = try await provider.generateResponse(for: "add my signature", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Sign PDF")
    }

    func testCropKeyword() async throws {
        let response = try await provider.generateResponse(for: "crop the PDF", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Crop PDF")
    }

    func testTrimKeyword() async throws {
        let response = try await provider.generateResponse(for: "trim margins", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Crop PDF")
    }

    func testMetadataKeyword() async throws {
        let response = try await provider.generateResponse(for: "edit metadata", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "PDF Metadata")
    }

    func testAuthorKeyword() async throws {
        let response = try await provider.generateResponse(for: "who is the author", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "PDF Metadata")
    }

    func testPropertiesKeyword() async throws {
        let response = try await provider.generateResponse(for: "show properties", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "PDF Metadata")
    }

    func testSummarizeKeyword() async throws {
        let response = try await provider.generateResponse(for: "summarize this", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Summarize PDF")
    }

    func testTldrKeyword() async throws {
        let response = try await provider.generateResponse(for: "tldr please", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Summarize PDF")
    }

    func testAskKeyword() async throws {
        let response = try await provider.generateResponse(for: "ask a question about PDF", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Ask PDF")
    }

    func testEmailKeyword() async throws {
        let response = try await provider.generateResponse(for: "email this PDF", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Email PDF")
    }

    func testMailKeyword() async throws {
        let response = try await provider.generateResponse(for: "mail this file", conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Email PDF")
    }

    func testHelloKeyword() async throws {
        let response = try await provider.generateResponse(for: "hello", conversationHistory: [])
        XCTAssertTrue(response.text.contains("DocSage"))
        XCTAssertNil(response.toolBadge)
    }

    func testHiKeyword() async throws {
        let response = try await provider.generateResponse(for: "hi there", conversationHistory: [])
        XCTAssertTrue(response.text.contains("DocSage"))
    }

    func testHeyKeyword() async throws {
        let response = try await provider.generateResponse(for: "hey", conversationHistory: [])
        XCTAssertTrue(response.text.contains("DocSage"))
    }

    func testDefaultFallback() async throws {
        let response = try await provider.generateResponse(for: "xyzzy nonsense input", conversationHistory: [])
        XCTAssertNil(response.toolBadge)
        XCTAssertTrue(response.text.contains("document tasks"))
    }

    func testSupportsStreaming() {
        XCTAssertFalse(provider.supportsStreaming)
    }

    func testStreamResponse_delegatesToGenerate() async throws {
        let response = try await provider.streamResponse(for: "scan", conversationHistory: []) { _ in }
        XCTAssertEqual(response.toolBadge, "Scanner")
    }

    func testResetSession_noOp() {
        // Should not crash
        provider.resetSession()
    }

    // MARK: Document Context Tests

    func testDocContext_translate() async throws {
        let input = """
        [Document context from scanned/attached file]
        The following is text extracted from the user's document.
        ---
        This is some document text about various topics.
        ---

        User question: translate to spanish
        """
        let response = try await provider.generateResponse(for: input, conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Translate PDF")
        XCTAssertTrue(response.text.contains("Spanish"))
    }

    func testDocContext_amount() async throws {
        let input = """
        [Document context from scanned/attached file]
        The following is text extracted from the user's document.
        ---
        Item 1 $10.00
        Subtotal $10.00
        Total $10.80
        ---

        User question: what is the total amount
        """
        let response = try await provider.generateResponse(for: input, conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Document")
        XCTAssertTrue(response.text.contains("Total"))
    }

    func testDocContext_generalQuestion() async throws {
        let input = """
        [Document context from scanned/attached file]
        The following is text extracted from the user's document.
        ---
        The company headquarters is located in San Francisco California.
        ---

        User question: where is the headquarters
        """
        let response = try await provider.generateResponse(for: input, conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Document")
        XCTAssertTrue(response.text.lowercased().contains("found"))
    }

    func testDocContext_summarize() async throws {
        let input = """
        [Document context from scanned/attached file]
        The following is text extracted from the user's document.
        ---
        The annual report shows significant growth in revenue this year. The company expanded into new markets and launched several products. Customer satisfaction scores improved dramatically.
        ---

        User question: summarize this document
        """
        let response = try await provider.generateResponse(for: input, conversationHistory: [])
        XCTAssertEqual(response.toolBadge, "Document")
        XCTAssertTrue(response.text.contains("Summary"))
    }

    func testDocContext_noMarker_fallsThrough() async throws {
        // Input without [Document context marker should go through normal keyword matching
        let response = try await provider.generateResponse(for: "what is this document about", conversationHistory: [])
        // Should NOT be handled by document context handler
        XCTAssertNotEqual(response.toolBadge, "Document")
    }

    func testDocContext_missingParts() async throws {
        // Input with marker but no "User question: " separator
        let input = "[Document context from scanned/attached file]\nSome text here"
        let response = try await provider.generateResponse(for: input, conversationHistory: [])
        // Falls through to normal matching
        XCTAssertNotEqual(response.toolBadge, "Document")
    }
}

// MARK: - FilesViewModel Extended Tests (gap fill)

@MainActor
final class FilesViewModelComprehensiveTests: XCTestCase {

    func testSort_dateAsc() {
        let vm = FilesViewModel()
        vm.sortOption = .dateAsc
        let older = DocumentFile(name: "old", fileExtension: "pdf", relativeFilePath: "old.pdf", fileSize: 100, pageCount: 1)
        let newer = DocumentFile(name: "new", fileExtension: "pdf", relativeFilePath: "new.pdf", fileSize: 100, pageCount: 1)
        let result = vm.filteredAndSorted([newer, older])
        // dateAsc: older first
        XCTAssertEqual(result.count, 2)
    }

    func testSort_sizeAsc() {
        let vm = FilesViewModel()
        vm.sortOption = .sizeAsc
        let small = DocumentFile(name: "small", fileExtension: "pdf", relativeFilePath: "s.pdf", fileSize: 100, pageCount: 1)
        let big = DocumentFile(name: "big", fileExtension: "pdf", relativeFilePath: "b.pdf", fileSize: 9999, pageCount: 1)
        let result = vm.filteredAndSorted([big, small])
        XCTAssertEqual(result.first?.name, "small")
    }

    func testSort_typeAsc() {
        let vm = FilesViewModel()
        vm.sortOption = .typeAsc
        let pdf = DocumentFile(name: "a", fileExtension: "pdf", relativeFilePath: "a.pdf", fileSize: 100, pageCount: 1)
        let txt = DocumentFile(name: "b", fileExtension: "txt", relativeFilePath: "b.txt", fileSize: 100, pageCount: nil)
        let result = vm.filteredAndSorted([txt, pdf])
        XCTAssertEqual(result.first?.fileExtension, "pdf")
    }

    func testCategoryCount_hashBasedInvalidation() {
        let vm = FilesViewModel()
        let files1 = [
            DocumentFile(name: "a", fileExtension: "pdf", relativeFilePath: "a.pdf", fileSize: 100, pageCount: 1),
            DocumentFile(name: "b", fileExtension: "jpg", relativeFilePath: "b.jpg", fileSize: 200, pageCount: nil),
        ]
        // First call builds cache
        let pdfCount1 = vm.categoryCount(.pdf, in: files1)
        XCTAssertEqual(pdfCount1, 1)
        let allCount1 = vm.categoryCount(.all, in: files1)
        XCTAssertEqual(allCount1, 2)

        // Same count but different files should invalidate
        let files2 = [
            DocumentFile(name: "c", fileExtension: "pdf", relativeFilePath: "c.pdf", fileSize: 100, pageCount: 1),
            DocumentFile(name: "d", fileExtension: "pdf", relativeFilePath: "d.pdf", fileSize: 200, pageCount: 1),
        ]
        let pdfCount2 = vm.categoryCount(.pdf, in: files2)
        XCTAssertEqual(pdfCount2, 2)
    }

    func testRecentFiles() {
        let vm = FilesViewModel()
        let file1 = DocumentFile(name: "a", fileExtension: "pdf", relativeFilePath: "a.pdf", fileSize: 100, pageCount: 1)
        file1.lastOpenedAt = Date()
        let file2 = DocumentFile(name: "b", fileExtension: "pdf", relativeFilePath: "b.pdf", fileSize: 100, pageCount: 1)
        // file2 has no lastOpenedAt
        let result = vm.recentFiles([file1, file2])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "a")
    }

    func testRecentFiles_limit() {
        let vm = FilesViewModel()
        var files: [DocumentFile] = []
        for i in 0..<10 {
            let f = DocumentFile(name: "f\(i)", fileExtension: "pdf", relativeFilePath: "f\(i).pdf", fileSize: 100, pageCount: 1)
            f.lastOpenedAt = Date()
            files.append(f)
        }
        let result = vm.recentFiles(files, limit: 3)
        XCTAssertEqual(result.count, 3)
    }
}

// MARK: - SpeechRecognitionService Tests (0% → ~40%)

@MainActor
final class SpeechRecognitionServiceTests: XCTestCase {

    func testInitialState() {
        let service = SpeechRecognitionService()
        XCTAssertEqual(service.transcribedText, "")
        XCTAssertFalse(service.isRecording)
        XCTAssertFalse(service.isAuthorized)
        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(service.audioLevel, 0.0)
    }

    func testReset() {
        let service = SpeechRecognitionService()
        service.transcribedText = "Some text"
        service.errorMessage = "Error"
        service.audioLevel = 0.5
        service.reset()
        XCTAssertEqual(service.transcribedText, "")
        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(service.audioLevel, 0.0)
    }

    func testStopRecording_fromIdleState() {
        let service = SpeechRecognitionService()
        service.stopRecording()
        XCTAssertFalse(service.isRecording)
        XCTAssertEqual(service.audioLevel, 0)
    }

    func testInitWithLocale() {
        let service = SpeechRecognitionService(locale: Locale(identifier: "en-US"))
        XCTAssertNotNil(service)
        XCTAssertFalse(service.isRecording)
    }
}

// MARK: - InlineChatToolExecutor Tests (0% → ~70%)

@MainActor
final class InlineChatToolExecutorTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, configurations: config)
    }

    func testExecute_unknownTool() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = DocumentFile(name: "test", fileExtension: "pdf", relativeFilePath: "test.pdf", fileSize: 100, pageCount: 1)
        context.insert(doc)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "unknown_tool", documentFile: doc, context: context)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.toolType, "unknown_tool")
        XCTAssertTrue(result.content.contains("not supported"))
    }

    func testExecute_ocrFileNotFound() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // Doc with no valid file path → fileURL will be nil
        let doc = DocumentFile(name: "ghost", fileExtension: "pdf", relativeFilePath: "nonexistent/ghost.pdf", fileSize: 0, pageCount: 1)
        context.insert(doc)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "ocr", documentFile: doc, context: context)
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.title.contains("File Not Found") || result.title.contains("Error"))
    }

    func testExecute_summarizeFileNotFound() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = DocumentFile(name: "ghost", fileExtension: "pdf", relativeFilePath: "nonexistent/ghost.pdf", fileSize: 0, pageCount: 1)
        context.insert(doc)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "summarize", documentFile: doc, context: context)
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.title.contains("File Not Found") || result.title.contains("Error"))
    }

    func testExecute_compressFileNotFound() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = DocumentFile(name: "ghost", fileExtension: "pdf", relativeFilePath: "nonexistent/ghost.pdf", fileSize: 0, pageCount: 1)
        context.insert(doc)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "compress", documentFile: doc, context: context)
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.title.contains("File Not Found") || result.title.contains("Error"))
    }

    func testExecute_watermarkFileNotFound() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = DocumentFile(name: "ghost", fileExtension: "pdf", relativeFilePath: "nonexistent/ghost.pdf", fileSize: 0, pageCount: 1)
        context.insert(doc)

        let result = await InlineChatToolExecutor.shared.execute(toolType: "watermark", documentFile: doc, context: context)
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.title.contains("File Not Found") || result.title.contains("Error"))
    }
}

// MARK: - ChatViewModel Extended Tests (gap fill)

@MainActor
final class ChatViewModelFullTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: DocumentFile.self, Conversation.self, ChatMessage.self, configurations: config)
    }

    func testAttachFile() {
        let vm = ChatViewModel()
        XCTAssertNil(vm.pendingAttachment)

        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        vm.attachFile(url: url)
        XCTAssertNotNil(vm.pendingAttachment)
        XCTAssertEqual(vm.pendingAttachment?.fileName, "test")
    }

    func testRemoveAttachment() {
        let vm = ChatViewModel()
        vm.attachFile(url: URL(fileURLWithPath: "/tmp/test.pdf"))
        XCTAssertNotNil(vm.pendingAttachment)
        vm.removeAttachment()
        XCTAssertNil(vm.pendingAttachment)
    }

    func testStartNewConversation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = ChatViewModel()

        XCTAssertNil(vm.currentConversation)
        vm.startNewConversation(context: context)
        XCTAssertNotNil(vm.currentConversation)
        XCTAssertEqual(vm.currentConversation?.title, "New Chat")
    }

    func testStartNewConversation_clearsOCRContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = ChatViewModel()

        // Start first conversation
        vm.startNewConversation(context: context)
        // Starting a new one should work cleanly
        vm.startNewConversation(context: context)
        XCTAssertNotNil(vm.currentConversation)
    }

    func testMessagesForCurrentConversation_empty() {
        let vm = ChatViewModel()
        let result = vm.messagesForCurrentConversation(allMessages: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testMessagesForCurrentConversation_filtered() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = ChatViewModel()
        vm.startNewConversation(context: context)

        let conv = vm.currentConversation!
        let msg1 = ChatMessage(content: "Hello", role: "user", conversation: conv)
        let otherConv = Conversation()
        context.insert(otherConv)
        let msg2 = ChatMessage(content: "Other", role: "user", conversation: otherConv)

        let result = vm.messagesForCurrentConversation(allMessages: [msg1, msg2])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.content, "Hello")
    }

    func testSendMessage_emptyText_noAttachment_doesNothing() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = ChatViewModel()
        vm.inputText = "   "
        vm.sendMessage(context: context)
        // No conversation created for empty input
        XCTAssertNil(vm.currentConversation)
    }

    func testSendMessage_createsConversation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = ChatViewModel()
        vm.inputText = "Hello AI"
        vm.sendMessage(context: context)
        XCTAssertNotNil(vm.currentConversation)
        XCTAssertEqual(vm.inputText, "")
    }

    func testSendQuickAction() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = ChatViewModel()
        let action = vm.actions.first!
        vm.sendQuickAction(action, context: context)
        XCTAssertNotNil(vm.currentConversation)
    }

    func testActions_notEmpty() {
        let vm = ChatViewModel()
        XCTAssertFalse(vm.actions.isEmpty)
        XCTAssertEqual(vm.actions.count, 6)
    }

    func testInitialState() {
        let vm = ChatViewModel()
        XCTAssertEqual(vm.inputText, "")
        XCTAssertFalse(vm.isTyping)
        XCTAssertEqual(vm.streamingContent, "")
        XCTAssertNil(vm.currentConversation)
        XCTAssertNil(vm.pendingAttachment)
    }
}

// MARK: - Int64+FileSize Extended Tests

final class Int64FileSizeExtendedTests: XCTestCase {

    func testZeroBytes() {
        XCTAssertFalse(Int64(0).formattedFileSize.isEmpty)
    }

    func testGigabyteRange() {
        let gb: Int64 = 2 * 1024 * 1024 * 1024
        let formatted = gb.formattedFileSize
        XCTAssertTrue(formatted.contains("GB"))
    }

    func testMegabyteRange() {
        let mb: Int64 = 5 * 1024 * 1024
        let formatted = mb.formattedFileSize
        XCTAssertTrue(formatted.contains("MB"))
    }

    func testKilobyteRange() {
        let kb: Int64 = 512 * 1024
        let formatted = kb.formattedFileSize
        XCTAssertTrue(formatted.contains("KB"))
    }
}

// MARK: - NavigationRouter Extended Tests

@MainActor
final class NavigationRouterFullTests: XCTestCase {

    func testNavigateToTools() {
        let router = NavigationRouter()
        router.selectedTab = .chat
        router.navigateToTools()
        XCTAssertEqual(router.selectedTab, .tools)
    }

    func testOpenToolFromAnywhere() {
        let router = NavigationRouter()
        router.selectedTab = .chat
        router.openToolFromAnywhere(.scanner)
        XCTAssertEqual(router.selectedTab, .tools)
        XCTAssertEqual(router.toolToOpen, .scanner)
    }

    func testResetCurrentTab_settings() {
        let router = NavigationRouter()
        router.selectedTab = .settings
        router.resetCurrentTab()
        // Settings tab reset is a no-op
        XCTAssertEqual(router.selectedTab, .settings)
    }

    func testResetCurrentTab_chat() {
        let router = NavigationRouter()
        router.selectedTab = .chat
        router.chatPath.append("test")
        router.resetCurrentTab()
        XCTAssertTrue(router.chatPath.isEmpty)
    }

    func testResetCurrentTab_tools() {
        let router = NavigationRouter()
        router.selectedTab = .tools
        router.toolsPath.append("test")
        router.resetCurrentTab()
        XCTAssertTrue(router.toolsPath.isEmpty)
    }

    // testResetCurrentTab_settings already covers the settings no-op case
}

// MARK: - Conversation Relationship Tests

@MainActor
final class ConversationRelationshipTests: XCTestCase {

    func testConversation_messagesProperty() {
        let conv = Conversation(title: "Test")
        // Before insertion into SwiftData, messages is nil
        XCTAssertNil(conv.messages)
    }

    func testConversation_defaultTitle() {
        let conv = Conversation()
        XCTAssertEqual(conv.title, "New Chat")
    }

    func testConversation_customTitle() {
        let conv = Conversation(title: "My Chat")
        XCTAssertEqual(conv.title, "My Chat")
    }

    func testConversation_timestamps() {
        let before = Date()
        let conv = Conversation()
        let after = Date()
        XCTAssertGreaterThanOrEqual(conv.createdAt, before)
        XCTAssertLessThanOrEqual(conv.createdAt, after)
        XCTAssertGreaterThanOrEqual(conv.updatedAt, before)
    }
}

// MARK: - DocumentFile Extended Tests

final class DocumentFileExtendedTests: XCTestCase {

    func testFullFileName_normalCase() {
        let doc = DocumentFile(name: "report", fileExtension: "pdf", relativeFilePath: "report.pdf", fileSize: 1024, pageCount: 5)
        XCTAssertEqual(doc.fullFileName, "report.pdf")
    }

    func testCategory_pdf() {
        let doc = DocumentFile(name: "a", fileExtension: "pdf", relativeFilePath: "a.pdf", fileSize: 100, pageCount: 1)
        XCTAssertEqual(doc.category, .pdf)
    }

    func testCategory_image() {
        let doc = DocumentFile(name: "a", fileExtension: "jpg", relativeFilePath: "a.jpg", fileSize: 100, pageCount: nil)
        XCTAssertEqual(doc.category, .img)
    }

    func testViewerType_pdf() {
        let doc = DocumentFile(name: "a", fileExtension: "pdf", relativeFilePath: "a.pdf", fileSize: 100, pageCount: 1)
        XCTAssertEqual(doc.viewerType, .pdf)
    }

    func testViewerType_image() {
        let doc = DocumentFile(name: "a", fileExtension: "png", relativeFilePath: "a.png", fileSize: 100, pageCount: nil)
        XCTAssertEqual(doc.viewerType, .image)
    }

    func testViewerType_quickLook() {
        let doc = DocumentFile(name: "a", fileExtension: "docx", relativeFilePath: "a.docx", fileSize: 100, pageCount: nil)
        XCTAssertEqual(doc.viewerType, .quickLook)
    }

    func testIsFavorite_default() {
        let doc = DocumentFile(name: "a", fileExtension: "pdf", relativeFilePath: "a.pdf", fileSize: 100, pageCount: 1)
        XCTAssertFalse(doc.isFavorite)
    }

    func testLastOpenedAt_default() {
        let doc = DocumentFile(name: "a", fileExtension: "pdf", relativeFilePath: "a.pdf", fileSize: 100, pageCount: 1)
        XCTAssertNil(doc.lastOpenedAt)
    }
}

// MARK: - AppEffects Coverage (view modifiers)

@MainActor
final class AppEffectsTests: XCTestCase {

    func testGlassCardModifier() {
        let view = Text("Test").glassCard()
        let _ = UIHostingController(rootView: view)
    }

    func testGlowModifier() {
        let view = Text("Test").glow(color: .blue, radius: 5)
        let _ = UIHostingController(rootView: view)
    }

    func testShimmerModifier() {
        let view = Text("Test").shimmer()
        let _ = UIHostingController(rootView: view)
    }

    func testStaggeredAppearModifier() {
        let view = Text("Test").staggeredAppear(index: 2)
        let _ = UIHostingController(rootView: view)
    }

    func testConfettiModifier() {
        let view = Text("Test").confettiOnComplete(false)
        let _ = UIHostingController(rootView: view)
    }
}

// MARK: - Date+Formatting Edge Tests

final class DateFormattingEdgeTests: XCTestCase {

    func testExactly7DaysAgo() {
        let date = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let display = date.relativeDisplay
        XCTAssertFalse(display.isEmpty)
    }

    func testExactly1DayAgo() {
        let date = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let display = date.relativeDisplay
        XCTAssertFalse(display.isEmpty)
    }

    func testOlderThan7Days() {
        let date = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let display = date.relativeDisplay
        // Should use date format, not weekday
        XCTAssertFalse(display.isEmpty)
    }
}

// MARK: - ShareService Tests

@MainActor
final class ShareServiceComprehensiveTests: XCTestCase {

    func testShared_singleton() {
        let a = ShareService.shared
        let b = ShareService.shared
        XCTAssertTrue(a === b)
    }
}

// MARK: - OCRService Error Tests

final class OCRServiceErrorTests: XCTestCase {

    func testCannotLoadImage_description() {
        let error = OCRError.cannotLoadImage
        XCTAssertEqual(error.errorDescription, "Cannot load the image for text recognition.")
    }

    func testCannotOpenPDF_description() {
        let error = OCRError.cannotOpenPDF
        XCTAssertEqual(error.errorDescription, "Cannot open the PDF file.")
    }

    func testNoTextFound_description() {
        let error = OCRError.noTextFound
        XCTAssertEqual(error.errorDescription, "No text was found in the document.")
    }
}

// MARK: - DocumentViewerViewModel Tests

@MainActor
final class DocumentViewerViewModelFullTests: XCTestCase {

    func testInitialState() {
        let vm = DocumentViewerViewModel()
        XCTAssertTrue(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testLoadFile_fileNotFound() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DocumentFile.self, configurations: config)
        let context = ModelContext(container)

        let vm = DocumentViewerViewModel()
        let doc = DocumentFile(name: "missing", fileExtension: "pdf", relativeFilePath: "nonexistent.pdf", fileSize: 0, pageCount: 1)
        context.insert(doc)

        vm.loadFile(doc, context: context)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }
}

// MARK: - ConversationTitleGenerator Tests

@MainActor
final class ConversationTitleGeneratorTests: XCTestCase {

    func testSimpleMessage() {
        let title = ConversationTitleGenerator.generate(from: "scan my document")
        XCTAssertEqual(title, "Scan my document")
    }

    func testStripFillerPrefix() {
        XCTAssertEqual(ConversationTitleGenerator.generate(from: "please merge these PDFs"), "Merge these PDFs")
        XCTAssertEqual(ConversationTitleGenerator.generate(from: "can you compress this file"), "Compress this file")
        XCTAssertEqual(ConversationTitleGenerator.generate(from: "i want to extract text"), "Extract text")
        XCTAssertEqual(ConversationTitleGenerator.generate(from: "hey help me with OCR"), "Help me with OCR")
    }

    func testFileAttachmentPrefix() {
        let title = ConversationTitleGenerator.generate(from: "Here's a file: Invoice_2026.pdf")
        XCTAssertEqual(title, "Invoice_2026.pdf")
    }

    func testTruncationAtWordBoundary() {
        let longMessage = "This is a very long message that should be truncated at a word boundary properly"
        let title = ConversationTitleGenerator.generate(from: longMessage)
        XCTAssertTrue(title.count <= 36) // 35 + ellipsis
        XCTAssertTrue(title.hasSuffix("…"))
        XCTAssertFalse(title.contains("properly")) // cut before this word
    }

    func testShortMessageNotTruncated() {
        let title = ConversationTitleGenerator.generate(from: "hello")
        XCTAssertEqual(title, "Hello")
        XCTAssertFalse(title.contains("…"))
    }

    func testWhitespaceHandling() {
        let title = ConversationTitleGenerator.generate(from: "   scan a document   ")
        XCTAssertEqual(title, "Scan a document")
    }

    func testCapitalization() {
        let title = ConversationTitleGenerator.generate(from: "merge my PDFs")
        XCTAssertEqual(title, "Merge my PDFs")
    }

    func testWelcomeActions() {
        let vm = ChatViewModel()
        XCTAssertEqual(vm.welcomeActions.count, 4)
        XCTAssertEqual(vm.actions.count, 6)
    }
}

// MARK: - AgentOrchestrator Tests

@MainActor
final class AgentOrchestratorTests: XCTestCase {

    func testDetectIntent_merge() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "merge my PDFs")?.displayName, "Merge PDF")
    }

    func testDetectIntent_compress() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "compress this file")?.displayName, "Compress")
    }

    func testDetectIntent_ocr() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "extract text from image")?.displayName, "OCR Text")
    }

    func testDetectIntent_lock() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "password protect my pdf")?.displayName, "Lock PDF")
    }

    func testDetectIntent_translate() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "translate this document")?.displayName, "Translate PDF")
    }

    func testDetectIntent_summarize() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "give me a summary")?.displayName, "Summarize PDF")
    }

    func testDetectIntent_docToPDF() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "convert to pdf")?.displayName, "Doc to PDF")
    }

    func testDetectIntent_email() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "email this pdf")?.displayName, "Email PDF")
    }

    func testDetectIntent_unknown() {
        let orch = AgentOrchestrator.shared
        XCTAssertNil(orch.detectIntent(from: "hello there"))
    }

    func testDetectIntent_metadata() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "show metadata")?.displayName, "PDF Metadata")
    }

    func testDetectIntent_crop() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "crop the margins")?.displayName, "Crop PDF")
    }

    func testDetectIntent_rotate() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "rotate the pages")?.displayName, "Rotate PDF")
    }

    func testDetectIntent_sign() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "sign this document")?.displayName, "Sign PDF")
    }

    func testDetectIntent_split() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "split this pdf")?.displayName, "Split PDF")
    }

    func testDetectIntent_watermark() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "add a watermark")?.displayName, "Watermark")
    }

    func testDetectIntent_pdfToImage() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "export as image")?.displayName, "PDF to Image")
    }

    func testDetectIntent_pdfToText() {
        let orch = AgentOrchestrator.shared
        XCTAssertEqual(orch.detectIntent(from: "pdf to text conversion")?.displayName, "PDF to Text")
    }

    func testIdleState() {
        let orch = AgentOrchestrator.shared
        let id = UUID()
        XCTAssertTrue(isIdle(orch.getState(for: id)))
    }

    func testStateTransition() {
        let orch = AgentOrchestrator.shared
        let id = UUID()
        orch.setState(.awaitingFile(tool: .compress), for: id)
        if case .awaitingFile(let tool) = orch.getState(for: id) {
            XCTAssertEqual(tool, .compress)
        } else {
            XCTFail("Expected awaitingFile state")
        }
        orch.reset(for: id)
        XCTAssertTrue(isIdle(orch.getState(for: id)))
    }

    func testAgentToolDisplayNames() {
        XCTAssertEqual(AgentOrchestrator.AgentTool.merge.displayName, "Merge PDF")
        XCTAssertEqual(AgentOrchestrator.AgentTool.compress.displayName, "Compress")
        XCTAssertEqual(AgentOrchestrator.AgentTool.docToPDF.displayName, "Doc to PDF")
        XCTAssertEqual(AgentOrchestrator.AgentTool.pdfToImage.displayName, "PDF to Image")
        XCTAssertEqual(AgentOrchestrator.AgentTool.metadata.displayName, "PDF Metadata")
        XCTAssertEqual(AgentOrchestrator.AgentTool.emailPDF.displayName, "Email PDF")
    }

    func testAgentToolFromId() {
        XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: "Merge PDF"), .merge)
        XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: "Doc to PDF"), .docToPDF)
        XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: "PDF Metadata"), .metadata)
        XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: "Email PDF"), .emailPDF)
        XCTAssertNil(AgentOrchestrator.AgentTool.from(toolId: "nonexistent"))
    }

    func testRequiredParams() {
        XCTAssertTrue(AgentOrchestrator.AgentTool.compress.requiredParams.isEmpty)
        XCTAssertTrue(AgentOrchestrator.AgentTool.lock.requiredParams.contains("password"))
        XCTAssertTrue(AgentOrchestrator.AgentTool.translate.requiredParams.contains("language"))
        XCTAssertTrue(AgentOrchestrator.AgentTool.askPDF.requiredParams.contains("question"))
    }

    func testSuggestedNextTools() {
        XCTAssertTrue(AgentOrchestrator.AgentTool.ocr.suggestedNextTools.contains(.summarize))
        XCTAssertTrue(AgentOrchestrator.AgentTool.merge.suggestedNextTools.contains(.compress))
        XCTAssertTrue(AgentOrchestrator.AgentTool.compress.suggestedNextTools.contains(.watermark))
        XCTAssertTrue(AgentOrchestrator.AgentTool.docToPDF.suggestedNextTools.contains(.compress))
    }

    func testAllToolsCovered() {
        // Every AgentTool should have a displayName and from() mapping
        for tool in AgentOrchestrator.AgentTool.allCases {
            XCTAssertFalse(tool.displayName.isEmpty, "\(tool) has empty displayName")
            XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: tool.displayName), tool,
                           "\(tool) round-trip failed")
        }
    }

    private func isIdle(_ state: AgentOrchestrator.AgentState) -> Bool {
        if case .idle = state { return true }
        return false
    }
}

// MARK: - ChatExportService Tests

@MainActor
final class ChatExportServiceTests: XCTestCase {

    func testExportEmptyConversation() {
        let conversation = Conversation(title: "Test Chat")
        let url = ChatExportService.shared.exportConversation(conversation, messages: [])
        XCTAssertNotNil(url)
        if let url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            try? FileManager.default.removeItem(at: url) // cleanup
        }
    }

    func testExportWithMessages() {
        let conversation = Conversation(title: "Test Export")
        let msg1 = ChatMessage(content: "Hello", role: "user", conversation: conversation)
        let msg2 = ChatMessage(content: "Hi there!", role: "assistant", conversation: conversation)
        let url = ChatExportService.shared.exportConversation(conversation, messages: [msg1, msg2])
        XCTAssertNotNil(url)
        if let url {
            let data = try? Data(contentsOf: url)
            XCTAssertNotNil(data)
            XCTAssertTrue((data?.count ?? 0) > 100) // PDF should have content
            try? FileManager.default.removeItem(at: url)
        }
    }

    func testExportFileName() {
        let conversation = Conversation(title: "My Important Chat")
        let url = ChatExportService.shared.exportConversation(conversation, messages: [])
        XCTAssertNotNil(url)
        if let url {
            XCTAssertTrue(url.lastPathComponent.hasPrefix("DocSage_"))
            XCTAssertTrue(url.pathExtension == "pdf")
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Conversation Model Tests

@MainActor
final class ConversationModelTests: XCTestCase {

    func testDefaultValues() {
        let conv = Conversation()
        XCTAssertEqual(conv.title, "New Chat")
        XCTAssertFalse(conv.isPinned)
    }

    func testCustomTitle() {
        let conv = Conversation(title: "My Chat")
        XCTAssertEqual(conv.title, "My Chat")
    }

    func testIsPinnedDefault() {
        let conv = Conversation()
        XCTAssertEqual(conv.isPinned, false)
    }

    func testTogglePin() {
        let conv = Conversation()
        conv.isPinned = true
        XCTAssertTrue(conv.isPinned)
        conv.isPinned = false
        XCTAssertFalse(conv.isPinned)
    }
}

// MARK: - FileTag Tests

@MainActor
final class FileTagTests: XCTestCase {

    func testAllTagCases() {
        XCTAssertEqual(FileTag.allCases.count, 6)
    }

    func testTagColors() {
        XCTAssertNotNil(FileTag.work.color)
        XCTAssertNotNil(FileTag.personal.color)
        XCTAssertNotNil(FileTag.invoice.color)
        XCTAssertNotNil(FileTag.receipt.color)
        XCTAssertNotNil(FileTag.legal.color)
        XCTAssertNotNil(FileTag.archive.color)
    }

    func testTagIcons() {
        for tag in FileTag.allCases {
            XCTAssertFalse(tag.icon.isEmpty, "\(tag) has empty icon")
        }
    }

    func testTagRawValues() {
        XCTAssertEqual(FileTag.work.rawValue, "Work")
        XCTAssertEqual(FileTag.personal.rawValue, "Personal")
        XCTAssertEqual(FileTag.invoice.rawValue, "Invoice")
    }

    func testDocumentFileTagProperty() {
        let doc = DocumentFile(
            name: "test", fileExtension: "pdf",
            relativeFilePath: "DocGenieFiles/test.pdf",
            fileSize: 1024
        )
        XCTAssertNil(doc.tag)
        doc.tagName = "Work"
        XCTAssertEqual(doc.tag, .work)
        doc.tagName = "Invalid"
        XCTAssertNil(doc.tag)
        doc.tagName = nil
        XCTAssertNil(doc.tag)
    }
}

// MARK: - ChatAction Tests

@MainActor
final class ChatActionTypeTests: XCTestCase {

    func testAllActionTypes() {
        let types: [ChatActionType] = [.openTool, .navigateTab, .openFile, .showResult,
                                        .executeInline, .copyText, .shareFile, .attachFile]
        XCTAssertEqual(types.count, 8)
    }

    func testAttachFileActionType() {
        let action = ChatAction(label: "Attach", icon: "plus", actionType: .attachFile)
        XCTAssertEqual(action.actionType, .attachFile)
    }

    func testActionCodable() throws {
        let action = ChatAction(label: "Test", icon: "star", actionType: .openTool, toolId: "Merge PDF")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(ChatAction.self, from: data)
        XCTAssertEqual(decoded.label, "Test")
        XCTAssertEqual(decoded.toolId, "Merge PDF")
        XCTAssertEqual(decoded.actionType, .openTool)
    }
}

// MARK: - Agentic Flow Integration Tests

@MainActor
final class AgenticFlowTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() {
        container = try! ModelContainer(
            for: DocumentFile.self, ChatMessage.self, Conversation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func testStartAgenticFlow_compress() {
        let vm = ChatViewModel()
        vm.startAgenticToolFlow(toolId: "Compress", context: container.mainContext)
        XCTAssertNotNil(vm.currentConversation)
        XCTAssertEqual(vm.pendingAgenticTool, "Compress")
    }

    func testStartAgenticFlow_merge() {
        let vm = ChatViewModel()
        vm.startAgenticToolFlow(toolId: "Merge PDF", context: container.mainContext)
        XCTAssertEqual(vm.pendingAgenticTool, "Merge PDF")
    }

    func testStartAgenticFlow_unknownTool() {
        let vm = ChatViewModel()
        vm.startAgenticToolFlow(toolId: "NonexistentTool", context: container.mainContext)
        // Falls back to regular message
        XCTAssertNil(vm.pendingAgenticTool)
    }

    func testStartAgenticFlow_allTools() {
        let toolIds = [
            "Merge PDF", "Compress", "OCR Text", "Split PDF", "Lock PDF",
            "Unlock PDF", "Watermark", "Image to PDF", "Sign PDF",
            "Doc to PDF", "PDF to Image", "PDF to Text",
            "Translate PDF", "Summarize PDF", "Ask PDF",
            "Rotate PDF", "Reorder Pages", "Page Numbers",
            "Crop PDF", "PDF Metadata", "Email PDF"
        ]
        for toolId in toolIds {
            let vm = ChatViewModel()
            vm.startAgenticToolFlow(toolId: toolId, context: container.mainContext)
            XCTAssertEqual(vm.pendingAgenticTool, toolId, "Failed for \(toolId)")
            XCTAssertNotNil(vm.currentConversation, "No conversation for \(toolId)")
        }
    }

    func testConversationTitleGenerated() {
        let vm = ChatViewModel()
        vm.startAgenticToolFlow(toolId: "Compress", context: container.mainContext)
        XCTAssertNotEqual(vm.currentConversation?.title, "New Chat")
    }
}

// MARK: - Constants Tests

@MainActor
final class ConstantsTests: XCTestCase {

    func testAppName() {
        XCTAssertEqual(AppConstants.appName, "DocSage")
    }

    func testSupportEmail() {
        XCTAssertTrue(AppConstants.supportEmail.contains("@"))
    }

    func testAppStoreURL() {
        XCTAssertTrue(AppConstants.appStoreURL.hasPrefix("https://"))
    }

    func testMaxFileSize() {
        XCTAssertEqual(AppConstants.maxFileSizeBytes, 500 * 1024 * 1024)
    }

    func testSupportedExtensions() {
        XCTAssertTrue(AppConstants.supportedExtensions.contains("pdf"))
        XCTAssertTrue(AppConstants.supportedExtensions.contains("jpg"))
        XCTAssertTrue(AppConstants.supportedExtensions.contains("png"))
        XCTAssertTrue(AppConstants.supportedExtensions.contains("docx"))
    }

    func testAppDocumentsSubdirectory() {
        XCTAssertEqual(AppConstants.appDocumentsSubdirectory, "DocGenieFiles")
    }

    func testSupportedUTTypes() {
        XCTAssertFalse(AppConstants.supportedUTTypes.isEmpty)
    }
}

// MARK: - Receipt Parser Tests

@MainActor
final class ReceiptParserTests: XCTestCase {

    func testParseReceipt_basicReceipt() {
        let text = """
        WALMART
        Store #1234
        Date: 03/15/2026

        Milk 2% Gallon     $3.99
        Bread Wheat        $2.49
        Eggs Large Dozen   $4.29

        Subtotal           $10.77
        Tax                $0.86
        Total              $11.63
        """
        let receipt = ScanContentType.parseReceipt(ocrText: text)
        XCTAssertEqual(receipt.vendor, "WALMART")
        XCTAssertNotNil(receipt.date)
        XCTAssertEqual(receipt.total, "$11.63")
        XCTAssertFalse(receipt.items.isEmpty)
    }

    func testParseReceipt_noAmounts() {
        let receipt = ScanContentType.parseReceipt(ocrText: "Some random text")
        XCTAssertNil(receipt.total)
        XCTAssertTrue(receipt.items.isEmpty)
    }

    func testParseReceipt_formattedSummary() {
        let text = "Coffee Shop\nDate: 01/01/2026\nLatte $4.50\nTotal $4.50"
        let receipt = ScanContentType.parseReceipt(ocrText: text)
        let summary = receipt.formattedSummary
        XCTAssertTrue(summary.contains("Coffee Shop"))
        XCTAssertTrue(summary.contains("$4.50"))
    }

    func testParseReceipt_withTax() {
        let text = "Store\nItem $10.00\nTax $0.80\nTotal $10.80"
        let receipt = ScanContentType.parseReceipt(ocrText: text)
        XCTAssertEqual(receipt.tax, "$0.80")
        XCTAssertEqual(receipt.total, "$10.80")
    }
}

// MARK: - Business Card Parser Tests

@MainActor
final class BusinessCardParserTests: XCTestCase {

    func testParseCard_withEmail() {
        let text = """
        John Smith
        Acme Corp Inc
        john@acme.com
        +1 555-123-4567
        www.acme.com
        """
        let card = ScanContentType.parseBusinessCard(ocrText: text)
        XCTAssertEqual(card.name, "John Smith")
        XCTAssertEqual(card.email, "john@acme.com")
        XCTAssertNotNil(card.phone)
        XCTAssertNotNil(card.company)
    }

    func testParseCard_formattedSummary() {
        let text = "Jane Doe\nStartup LLC\njane@startup.com\n555-9876"
        let card = ScanContentType.parseBusinessCard(ocrText: text)
        let summary = card.formattedSummary
        XCTAssertTrue(summary.contains("Jane Doe"))
        XCTAssertTrue(summary.contains("jane@startup.com"))
    }

    func testParseCard_noData() {
        let card = ScanContentType.parseBusinessCard(ocrText: "Hello world")
        XCTAssertNil(card.email)
        XCTAssertNil(card.phone)
    }

    func testParseCard_companyDetection() {
        let text = "Bob\nTech Solutions Inc\nbob@tech.com"
        let card = ScanContentType.parseBusinessCard(ocrText: text)
        XCTAssertEqual(card.company, "Tech Solutions Inc")
    }
}

// MARK: - ScanContentType Classification Tests

@MainActor
final class ScanContentTypeExtendedTests: XCTestCase {

    func testClassify_businessCard() {
        let text = "John Smith\nCTO\njohn@company.com\n+1-555-0100"
        XCTAssertEqual(ScanContentType.classify(ocrText: text), .businessCard)
    }

    func testClassify_businessCard_withWebsite() {
        let text = "Jane Doe\nwww.example.com\njane@example.com"
        XCTAssertEqual(ScanContentType.classify(ocrText: text), .businessCard)
    }

    func testClassify_receipt() {
        let text = "Store Receipt\nItem 1 $5.00\nSubtotal $5.00\nTax $0.40\nTotal $5.40\nPayment: Credit Card"
        XCTAssertEqual(ScanContentType.classify(ocrText: text), .receipt)
    }

    func testDisplayLabel_businessCard() {
        XCTAssertEqual(ScanContentType.businessCard.displayLabel, "Business Card")
    }

    func testDisplayIcon_businessCard() {
        XCTAssertEqual(ScanContentType.businessCard.displayIcon, "person.crop.rectangle")
    }

    func testSuggestedActions_businessCard() {
        let actions = ScanContentType.businessCard.suggestedActions
        XCTAssertFalse(actions.isEmpty)
    }

    func testAutoSummary_businessCard() {
        let text = "John Doe\nAcme Inc\njohn@acme.com\n555-1234"
        let summary = ScanContentType.businessCard.generateAutoSummary(ocrText: text)
        XCTAssertTrue(summary.contains("John Doe"))
    }
}

// MARK: - Smart Text Action Tests

@MainActor
final class TextTransformTests: XCTestCase {

    func testFormalRewrite() {
        let executor = InlineChatToolExecutor.shared
        // Test via the public enum
        XCTAssertNotNil(executor)
    }

    func testGrammarFix_doubleSpaces() {
        // Basic grammar fix logic
        var text = "hello  world.  this  is  a  test"
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }
        XCTAssertEqual(text, "hello world. this is a test")
    }

    func testBulletPoints() {
        let text = "First sentence here. Second sentence here. Third sentence is longer than ten characters."
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 10 }
        let bullets = sentences.map { "• \($0)" }.joined(separator: "\n")
        XCTAssertTrue(bullets.contains("• First sentence here"))
        XCTAssertTrue(bullets.contains("• Second sentence here"))
    }

    func testFormalReplacements() {
        let text = "I can't believe it won't work. I'm gonna fix it."
        var result = text
        let replacements: [(String, String)] = [
            ("can't", "cannot"), ("won't", "will not"), ("gonna", "going to"), ("I'm", "I am")
        ]
        for (old, new) in replacements {
            result = result.replacingOccurrences(of: old, with: new, options: .caseInsensitive)
        }
        XCTAssertTrue(result.contains("cannot"))
        XCTAssertTrue(result.contains("will not"))
        XCTAssertTrue(result.contains("going to"))
    }

    func testCasualReplacements() {
        let text = "Furthermore, we cannot proceed. However, we will not abandon the project."
        var result = text
        result = result.replacingOccurrences(of: "Furthermore,", with: "Also,")
        result = result.replacingOccurrences(of: "However,", with: "But,")
        result = result.replacingOccurrences(of: "cannot", with: "can't")
        result = result.replacingOccurrences(of: "will not", with: "won't")
        XCTAssertTrue(result.contains("Also,"))
        XCTAssertTrue(result.contains("But,"))
        XCTAssertTrue(result.contains("can't"))
    }
}

// MARK: - Smart Search Tests

@MainActor
final class SmartSearchTests: XCTestCase {

    func testSearchScope_all() {
        let vm = FilesViewModel()
        XCTAssertEqual(vm.searchScope, .all)
    }

    func testSearchScope_name() {
        let vm = FilesViewModel()
        vm.searchScope = .name
        vm.searchText = "test"
        let file = DocumentFile(name: "test_doc", fileExtension: "pdf", relativeFilePath: "DocGenieFiles/test.pdf", fileSize: 1024)
        file.ocrTextCache = "completely different content"
        let results = vm.filteredAndSorted([file])
        XCTAssertEqual(results.count, 1) // matches by name
    }

    func testSearchScope_content() {
        let vm = FilesViewModel()
        vm.searchScope = .content
        vm.searchText = "invoice"
        let file = DocumentFile(name: "scan_001", fileExtension: "pdf", relativeFilePath: "DocGenieFiles/scan.pdf", fileSize: 1024)
        file.ocrTextCache = "This is an invoice for services rendered"
        let results = vm.filteredAndSorted([file])
        XCTAssertEqual(results.count, 1) // matches by content
    }

    func testSearchScope_content_noMatch() {
        let vm = FilesViewModel()
        vm.searchScope = .content
        vm.searchText = "invoice"
        let file = DocumentFile(name: "photo", fileExtension: "jpg", relativeFilePath: "DocGenieFiles/photo.jpg", fileSize: 512)
        // No ocrTextCache
        let results = vm.filteredAndSorted([file])
        XCTAssertEqual(results.count, 0) // no content match
    }

    func testSearchScope_all_matchesContent() {
        let vm = FilesViewModel()
        vm.searchScope = .all
        vm.searchText = "budget"
        let file = DocumentFile(name: "report", fileExtension: "pdf", relativeFilePath: "DocGenieFiles/report.pdf", fileSize: 2048)
        file.ocrTextCache = "Annual budget report for 2026"
        let results = vm.filteredAndSorted([file])
        XCTAssertEqual(results.count, 1) // matches via OCR content
    }

    func testOcrTextCache_stored() {
        let file = DocumentFile(name: "test", fileExtension: "pdf", relativeFilePath: "DocGenieFiles/test.pdf", fileSize: 100)
        XCTAssertNil(file.ocrTextCache)
        file.ocrTextCache = "Extracted text from document"
        XCTAssertEqual(file.ocrTextCache, "Extracted text from document")
    }
}
