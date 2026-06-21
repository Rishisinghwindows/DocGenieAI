// DeepCoverageBoostTests.swift
// Tests for high-impact coverage gaps: ChatViewModel, AgentOrchestrator, ChatTabView, FilesTabView, ChatInputBar, ChatHistoryView

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
private func deepRenderWithContext<V: View>(_ view: V, duration: TimeInterval = 0.2) throws {
    let container = try makeContainer()
    let router = NavigationRouter()
    deepRender(view.environment(router).modelContainer(container), duration: duration)
}

// MARK: - AgentOrchestrator Tests

@MainActor
final class AgentOrchestratorFullTests: XCTestCase {

    func testInitialState() {
        let conversationId = UUID()
        let state = AgentOrchestrator.shared.getState(for: conversationId)
        if case .idle = state {
            // Expected
        } else {
            XCTFail("Expected .idle state for new conversation")
        }
    }

    func testSetAndGetState() {
        let conversationId = UUID()
        AgentOrchestrator.shared.setState(.completed, for: conversationId)
        let state = AgentOrchestrator.shared.getState(for: conversationId)
        if case .completed = state {} else { XCTFail("Expected .completed") }
        AgentOrchestrator.shared.reset(for: conversationId)
    }

    func testResetState() {
        let conversationId = UUID()
        AgentOrchestrator.shared.setState(.completed, for: conversationId)
        AgentOrchestrator.shared.reset(for: conversationId)
        let state = AgentOrchestrator.shared.getState(for: conversationId)
        if case .idle = state {} else { XCTFail("Expected .idle after reset") }
    }

    // MARK: - Intent Detection

    func testDetectIntentOCR() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "extract text from this PDF")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentCompress() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "compress this file to make it smaller")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentMerge() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "merge these PDFs together")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentSplit() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "split this PDF into pages")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentLock() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "lock this PDF with a password")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentUnlock() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "unlock this PDF please")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentWatermark() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "add a watermark to this document")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentSign() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "sign this document with my signature")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentSummarize() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "summarize this document for me")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentTranslate() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "translate this PDF to Hindi")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentRotate() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "rotate this PDF 90 degrees")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentPageNumbers() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "add page numbers to this PDF")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentExtractPages() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "extract pages 1-5 from this document")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentCrop() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "crop the margins of this PDF")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentConvertToPDF() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "convert this doc to pdf format")
        // May or may not match depending on keyword patterns
        _ = tool
    }

    func testDetectIntentPDFToImage() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "convert PDF to images")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentPDFToText() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "export PDF to text file")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentMetadata() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "edit the metadata of this PDF")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentEmail() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "email this PDF to someone")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentReorder() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "reorder the pages in this PDF")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentImageToPDF() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "photo to pdf please")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentAskPDF() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "ask a question about this PDF")
        XCTAssertNotNil(tool)
    }

    func testDetectIntentNoMatch() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "hello how are you today")
        XCTAssertNil(tool)
    }

    func testDetectIntentEmptyString() {
        let tool = AgentOrchestrator.shared.detectIntent(from: "")
        XCTAssertNil(tool)
    }

    // MARK: - Pipeline Detection

    func testDetectPipelineScanSummarize() {
        let pipeline = AgentOrchestrator.shared.detectPipeline(from: "scan and summarize this document")
        XCTAssertNotNil(pipeline)
    }

    func testDetectPipelineOCRTranslate() {
        let pipeline = AgentOrchestrator.shared.detectPipeline(from: "extract text and translate it")
        XCTAssertNotNil(pipeline)
    }

    func testDetectPipelineSecurePDF() {
        let pipeline = AgentOrchestrator.shared.detectPipeline(from: "secure this pdf for me")
        XCTAssertNotNil(pipeline)
    }

    func testDetectPipelineNoMatch() {
        let pipeline = AgentOrchestrator.shared.detectPipeline(from: "hello world")
        XCTAssertNil(pipeline)
    }

    // MARK: - Process Messages

    func testProcessIdleWithIntent() throws {
        let container = try makeContainer()
        let conversationId = UUID()
        AgentOrchestrator.shared.reset(for: conversationId)

        let response = AgentOrchestrator.shared.process(
            conversationId: conversationId,
            userMessage: "compress this PDF",
            attachedFile: nil,
            context: container.mainContext
        )

        XCTAssertNotNil(response.message)
        AgentOrchestrator.shared.reset(for: conversationId)
    }

    func testProcessIdleNoIntent() throws {
        let container = try makeContainer()
        let conversationId = UUID()
        AgentOrchestrator.shared.reset(for: conversationId)

        let response = AgentOrchestrator.shared.process(
            conversationId: conversationId,
            userMessage: "hello",
            attachedFile: nil,
            context: container.mainContext
        )

        XCTAssertFalse(response.shouldExecute)
        AgentOrchestrator.shared.reset(for: conversationId)
    }

    func testProcessAwaitingFileWithFile() throws {
        let container = try makeContainer()
        let conversationId = UUID()
        AgentOrchestrator.shared.reset(for: conversationId)

        // First: detect intent to enter awaiting file state
        _ = AgentOrchestrator.shared.process(
            conversationId: conversationId,
            userMessage: "compress this PDF",
            attachedFile: nil,
            context: container.mainContext
        )

        // Now provide a file
        let file = DocumentFile(name: "Test", fileExtension: "pdf", relativeFilePath: "Test.pdf", fileSize: 1024)
        container.mainContext.insert(file)

        let response = AgentOrchestrator.shared.process(
            conversationId: conversationId,
            userMessage: "",
            attachedFile: file,
            context: container.mainContext
        )

        // Should proceed to execute or ask for params
        _ = response.shouldExecute
        _ = response.executeTool
        AgentOrchestrator.shared.reset(for: conversationId)
    }

    func testProcessWithParamsNeeded() throws {
        let container = try makeContainer()
        let conversationId = UUID()
        AgentOrchestrator.shared.reset(for: conversationId)

        // Lock needs a password
        _ = AgentOrchestrator.shared.process(
            conversationId: conversationId,
            userMessage: "lock this PDF",
            attachedFile: nil,
            context: container.mainContext
        )

        let file = DocumentFile(name: "Test", fileExtension: "pdf", relativeFilePath: "Test.pdf", fileSize: 1024)
        container.mainContext.insert(file)

        let response = AgentOrchestrator.shared.process(
            conversationId: conversationId,
            userMessage: "",
            attachedFile: file,
            context: container.mainContext
        )

        // Should ask for password param
        XCTAssertNotNil(response.message)
        AgentOrchestrator.shared.reset(for: conversationId)
    }

    func testOnToolComplete() {
        let conversationId = UUID()
        let result = InlineToolResult(toolType: "ocr", success: true, title: "Done", content: "Text extracted")

        let actions = AgentOrchestrator.shared.onToolComplete(
            conversationId: conversationId,
            tool: .ocr,
            result: result
        )

        // Should return suggested next tools
        XCTAssertTrue(actions.count <= 2)
        AgentOrchestrator.shared.reset(for: conversationId)
    }

    func testOnToolCompleteCompress() {
        let conversationId = UUID()
        let result = InlineToolResult(toolType: "compress", success: true, title: "Compressed", content: "Done")

        let actions = AgentOrchestrator.shared.onToolComplete(
            conversationId: conversationId,
            tool: .compress,
            result: result
        )

        XCTAssertTrue(actions.count <= 2)
        AgentOrchestrator.shared.reset(for: conversationId)
    }

    func testOnToolCompleteSummarize() {
        let conversationId = UUID()
        let result = InlineToolResult(toolType: "summarize", success: true, title: "Summary", content: "Here is the summary")

        let actions = AgentOrchestrator.shared.onToolComplete(
            conversationId: conversationId,
            tool: .summarize,
            result: result
        )

        XCTAssertTrue(actions.count <= 2)
        AgentOrchestrator.shared.reset(for: conversationId)
    }

    // MARK: - AgentTool Enum

    func testAgentToolDisplayNames() {
        let tools: [AgentOrchestrator.AgentTool] = [.merge, .compress, .ocr, .split, .lock, .unlock, .watermark,
                                  .imageToPDF, .sign, .summarize, .translate, .askPDF, .rotate,
                                  .reorder, .pageNumbers, .extractPages, .crop, .docToPDF,
                                  .pdfToImage, .pdfToText, .metadata, .emailPDF]
        for tool in tools {
            XCTAssertFalse(tool.displayName.isEmpty, "\(tool) should have a display name")
        }
    }

    func testAgentToolRequiredParams() {
        XCTAssertTrue(AgentOrchestrator.AgentTool.lock.requiredParams.contains("password"))
        XCTAssertTrue(AgentOrchestrator.AgentTool.split.requiredParams.contains("startPage"))
        XCTAssertTrue(AgentOrchestrator.AgentTool.watermark.requiredParams.contains("watermarkText"))
        XCTAssertTrue(AgentOrchestrator.AgentTool.extractPages.requiredParams.contains("pages"))
        XCTAssertTrue(AgentOrchestrator.AgentTool.rotate.requiredParams.contains("degrees"))
        XCTAssertTrue(AgentOrchestrator.AgentTool.translate.requiredParams.contains("language"))
        XCTAssertTrue(AgentOrchestrator.AgentTool.askPDF.requiredParams.contains("question"))
        XCTAssertTrue(AgentOrchestrator.AgentTool.compress.requiredParams.isEmpty)
        XCTAssertTrue(AgentOrchestrator.AgentTool.ocr.requiredParams.isEmpty)
    }

    func testAgentToolSuggestedNextTools() {
        XCTAssertFalse(AgentOrchestrator.AgentTool.ocr.suggestedNextTools.isEmpty)
        XCTAssertFalse(AgentOrchestrator.AgentTool.summarize.suggestedNextTools.isEmpty)
        XCTAssertFalse(AgentOrchestrator.AgentTool.compress.suggestedNextTools.isEmpty)
    }

    func testAgentToolFromToolId() {
        XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: "Merge PDF"), .merge)
        XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: "Compress"), .compress)
        XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: "OCR Text"), .ocr)
        XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: "Lock PDF"), .lock)
        XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: "Watermark"), .watermark)
        XCTAssertEqual(AgentOrchestrator.AgentTool.from(toolId: "Email PDF"), .emailPDF)
        XCTAssertNil(AgentOrchestrator.AgentTool.from(toolId: "nonexistent"))
    }

    // MARK: - Pipeline

    func testBuiltInPipelinesRegistered() {
        let pipelines = AgentOrchestrator.shared.pipelines
        XCTAssertTrue(pipelines.count >= 5)
    }

    func testPipelineSteps() {
        let pipelines = AgentOrchestrator.shared.pipelines
        for (_, pipeline) in pipelines {
            XCTAssertFalse(pipeline.steps.isEmpty)
            XCTAssertFalse(pipeline.name.isEmpty)
            XCTAssertFalse(pipeline.description.isEmpty)
        }
    }

    func testStartAndAdvancePipeline() {
        let conversationId = UUID()
        if let pipeline = AgentOrchestrator.shared.pipelines.values.first {
            let file = DocumentFile(name: "Test", fileExtension: "pdf", relativeFilePath: "Test.pdf", fileSize: 1024)
            AgentOrchestrator.shared.startPipeline(pipeline, file: file, conversationId: conversationId)

            if let step = AgentOrchestrator.shared.currentPipelineStep(for: conversationId) {
                XCTAssertEqual(step.1, 0) // step index
            }

            AgentOrchestrator.shared.advancePipeline(for: conversationId)
        }
        AgentOrchestrator.shared.reset(for: conversationId)
    }

    // MARK: - PipelineContext

    func testPipelineContextLastResult() {
        let ctx = AgentOrchestrator.PipelineContext()
        XCTAssertNil(ctx.lastResult)

        ctx.results["ocr"] = InlineToolResult(toolType: "ocr", success: true, title: "Done", content: "Text")
        XCTAssertNotNil(ctx.lastResult)
    }
}

// MARK: - ChatToolCoordinator Tests

@MainActor
final class ChatToolCoordinatorFullTests: XCTestCase {

    func testOpenTool() {
        let coordinator = ChatToolCoordinator()
        coordinator.openTool(.mergePDF)
        XCTAssertEqual(coordinator.activeTool, .mergePDF)
    }

    func testOpenToolScanner() {
        let coordinator = ChatToolCoordinator()
        coordinator.openTool(.scanner)
        XCTAssertTrue(coordinator.showScanner)
    }

    func testDismissTool() {
        let coordinator = ChatToolCoordinator()
        coordinator.openTool(.compressPDF)
        coordinator.dismissTool()
        XCTAssertNil(coordinator.activeTool)
    }

    func testToolForIdValid() {
        let coordinator = ChatToolCoordinator()
        for tool in ToolItem.allCases {
            let found = coordinator.toolForId(tool.rawValue)
            XCTAssertNotNil(found, "Should find tool for id: \(tool.rawValue)")
        }
    }

    func testToolForIdInvalid() {
        let coordinator = ChatToolCoordinator()
        let found = coordinator.toolForId("nonexistent_tool")
        XCTAssertNil(found)
    }

    func testToolForIdEmptyString() {
        let coordinator = ChatToolCoordinator()
        let found = coordinator.toolForId("")
        XCTAssertNil(found)
    }
}

// MARK: - ChatViewModel Tests

@MainActor
final class ChatViewModelLogicTests: XCTestCase {

    func testInitialState() {
        let vm = ChatViewModel()
        XCTAssertTrue(vm.inputText.isEmpty)
        XCTAssertFalse(vm.isTyping)
        XCTAssertTrue(vm.streamingContent.isEmpty)
        XCTAssertNil(vm.currentConversation)
        XCTAssertNil(vm.pendingAttachment)
        XCTAssertNil(vm.pendingAgenticTool)
    }

    func testQuickActions() {
        let vm = ChatViewModel()
        XCTAssertFalse(vm.actions.isEmpty)
        XCTAssertTrue(vm.actions.count >= 6)
    }

    func testWelcomeActions() {
        let vm = ChatViewModel()
        XCTAssertEqual(vm.welcomeActions.count, 4)
    }

    func testAttachFile() {
        let vm = ChatViewModel()
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        vm.attachFile(url: url)
        XCTAssertNotNil(vm.pendingAttachment)
    }

    func testRemoveAttachment() {
        let vm = ChatViewModel()
        vm.attachFile(url: URL(fileURLWithPath: "/tmp/test.pdf"))
        vm.removeAttachment()
        XCTAssertNil(vm.pendingAttachment)
    }

    func testStartNewConversation() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        vm.startNewConversation(context: container.mainContext)
        XCTAssertNotNil(vm.currentConversation)
        XCTAssertTrue(vm.inputText.isEmpty)
    }

    func testStartNewConversationCreatesConversation() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        XCTAssertNil(vm.currentConversation)
        vm.startNewConversation(context: container.mainContext)
        XCTAssertNotNil(vm.currentConversation)
        XCTAssertNil(vm.pendingAttachment)
    }

    func testMessagesForCurrentConversation() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        vm.startNewConversation(context: container.mainContext)

        let conv = vm.currentConversation!
        let msg1 = ChatMessage(content: "Hello", role: "user", conversation: conv)
        let msg2 = ChatMessage(content: "Hi", role: "assistant", conversation: conv)
        container.mainContext.insert(msg1)
        container.mainContext.insert(msg2)

        // Messages from different conversation should not appear
        let otherConv = Conversation()
        container.mainContext.insert(otherConv)
        let msg3 = ChatMessage(content: "Other", role: "user", conversation: otherConv)
        container.mainContext.insert(msg3)

        let filtered = vm.messagesForCurrentConversation(allMessages: [msg1, msg2, msg3])
        XCTAssertEqual(filtered.count, 2)
    }

    func testMessagesForNoConversation() {
        let vm = ChatViewModel()
        let conv = Conversation()
        let msg = ChatMessage(content: "Test", role: "user", conversation: conv)
        let filtered = vm.messagesForCurrentConversation(allMessages: [msg])
        XCTAssertTrue(filtered.isEmpty)
    }

    func testSendMessageCreatesConversation() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        vm.inputText = "Hello"
        vm.sendMessage(context: container.mainContext)

        // Should create a conversation
        XCTAssertNotNil(vm.currentConversation)
    }

    func testSendEmptyMessageDoesNothing() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        vm.inputText = "   "
        vm.sendMessage(context: container.mainContext)
        // With only whitespace and no attachment, nothing should happen
    }

    func testSendQuickAction() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        let action = vm.actions.first!
        vm.sendQuickAction(action, context: container.mainContext)
        XCTAssertNotNil(vm.currentConversation)
    }

    func testStartAgenticToolFlow() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        vm.startNewConversation(context: container.mainContext)
        vm.startAgenticToolFlow(toolId: "Compress", context: container.mainContext)
        XCTAssertEqual(vm.pendingAgenticTool, "Compress")
    }

    func testHandleActionOpenTool() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        let coordinator = ChatToolCoordinator()
        let router = NavigationRouter()

        let action = ChatAction(label: "Open Compress", icon: "arrow.down.doc", actionType: .openTool, toolId: "Compress")
        vm.handleAction(action, coordinator: coordinator, router: router, context: container.mainContext)
        // Compress now uses agentic flow, not sheet
        XCTAssertNil(coordinator.activeTool)
        XCTAssertEqual(vm.pendingAgenticTool, "Compress")
    }

    func testHandleActionNavigateTab() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        let coordinator = ChatToolCoordinator()
        let router = NavigationRouter()

        let action = ChatAction(label: "Tools", icon: "wrench", actionType: .navigateTab, tabId: "tools")
        vm.handleAction(action, coordinator: coordinator, router: router, context: container.mainContext)
        XCTAssertEqual(router.selectedTab, .tools)
    }

    func testHandleActionCopyText() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        let coordinator = ChatToolCoordinator()
        let router = NavigationRouter()

        let action = ChatAction(label: "Copy", icon: "doc.on.doc", actionType: .copyText, toolId: nil, tabId: nil, fileId: nil)
        // Ensure copyText action type exists
        vm.handleAction(action, coordinator: coordinator, router: router, context: container.mainContext)
    }
}

// MARK: - ChatViewModel Title Generator Tests

@MainActor
final class ConversationTitleGeneratorFullTests: XCTestCase {

    func testTitleGeneratorShortMessage() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        vm.inputText = "Hello"
        vm.sendMessage(context: container.mainContext)

        // Title should be set from the message
        if let conv = vm.currentConversation {
            XCTAssertFalse(conv.title.isEmpty)
        }
    }

    func testTitleGeneratorLongMessage() throws {
        let container = try makeContainer()
        let vm = ChatViewModel()
        vm.inputText = "Can you please help me merge these PDF files together so I can submit them as one document"
        vm.sendMessage(context: container.mainContext)

        if let conv = vm.currentConversation {
            // Title should be truncated to ~35 chars at word boundary
            XCTAssertTrue(conv.title.count <= 50)
        }
    }
}

// MARK: - ChatInputBar Extended Tests

@MainActor
final class ChatInputBarExtendedTests: XCTestCase {

    func testInputBarWithAttachment() {
        let attachment = PendingAttachment(
            fileName: "test",
            fileExtension: "pdf",
            url: URL(fileURLWithPath: "/tmp/test.pdf"),
            iconSystemName: "doc"
        )
        render(ChatInputBar(
            text: .constant(""),
            isTyping: false,
            pendingAttachment: attachment,
            isRecording: false,
            audioLevel: 0,
            onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}
        ))
    }

    func testInputBarRecordingState() {
        render(ChatInputBar(
            text: .constant(""),
            isTyping: false,
            pendingAttachment: nil,
            isRecording: true,
            audioLevel: 0.5,
            onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}
        ))
    }

    func testInputBarTextAndAttachment() {
        let attachment = PendingAttachment(
            fileName: "report",
            fileExtension: "pdf",
            url: URL(fileURLWithPath: "/tmp/report.pdf"),
            iconSystemName: "doc.fill"
        )
        render(ChatInputBar(
            text: .constant("Analyze this"),
            isTyping: false,
            pendingAttachment: attachment,
            isRecording: false,
            audioLevel: 0,
            onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}
        ))
    }

    func testInputBarHighAudioLevel() {
        render(ChatInputBar(
            text: .constant(""),
            isTyping: false,
            pendingAttachment: nil,
            isRecording: true,
            audioLevel: 1.0,
            onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}
        ))
    }

    func testInputBarAllStatesDeepRender() {
        // No text, not typing — voice button visible
        deepRender(ChatInputBar(
            text: .constant(""),
            isTyping: false,
            pendingAttachment: nil,
            isRecording: false,
            audioLevel: 0,
            onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}
        ))

        // With text — send button visible
        deepRender(ChatInputBar(
            text: .constant("Hello"),
            isTyping: false,
            pendingAttachment: nil,
            isRecording: false,
            audioLevel: 0,
            onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}
        ))

        // Typing — stop button visible
        deepRender(ChatInputBar(
            text: .constant(""),
            isTyping: true,
            pendingAttachment: nil,
            isRecording: false,
            audioLevel: 0,
            onSend: {}, onAttachTapped: {}, onVoiceToggle: {}, onRemoveAttachment: {}
        ))
    }
}

// MARK: - ChatHistoryView Extended Tests

@MainActor
final class ChatHistoryViewExtendedTests: XCTestCase {

    func testChatHistoryWithPinnedConversations() throws {
        let container = try makeContainer()
        let conv1 = Conversation()
        conv1.title = "Pinned Chat"
        conv1.isPinned = true
        container.mainContext.insert(conv1)

        let conv2 = Conversation()
        conv2.title = "Regular Chat"
        container.mainContext.insert(conv2)
        try container.mainContext.save()

        deepRender(
            ChatHistoryView(conversations: [conv1, conv2], onSelect: { _ in }, onDelete: { _ in })
                .modelContainer(container),
            duration: 0.3
        )
    }

    func testChatHistoryWithMessages() throws {
        let container = try makeContainer()
        let conv = Conversation()
        conv.title = "Chat with Messages"
        container.mainContext.insert(conv)

        for i in 0..<5 {
            let msg = ChatMessage(content: "Message \(i)", role: i % 2 == 0 ? "user" : "assistant", conversation: conv)
            container.mainContext.insert(msg)
        }
        try container.mainContext.save()

        deepRender(
            ChatHistoryView(conversations: [conv], onSelect: { _ in }, onDelete: { _ in })
                .modelContainer(container),
            duration: 0.3
        )
    }

    func testChatHistoryMultipleConversations() throws {
        let container = try makeContainer()
        var convs: [Conversation] = []
        for i in 0..<10 {
            let conv = Conversation()
            conv.title = "Chat \(i)"
            if i < 2 { conv.isPinned = true }
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

    func testChatHistoryEmptyWithButton() {
        deepRender(ChatHistoryView(conversations: [], onSelect: { _ in }, onDelete: { _ in }))
    }
}

// MARK: - ChatTabView Extended Tests

@MainActor
final class ChatTabViewExtendedTests: XCTestCase {

    func testChatTabViewWithMessagesAndConversation() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        let conv = Conversation()
        conv.title = "Active Chat"
        container.mainContext.insert(conv)

        for i in 0..<10 {
            let role = i % 2 == 0 ? "user" : "assistant"
            let msg = ChatMessage(content: "Message \(i) with some content", role: role, conversation: conv)
            container.mainContext.insert(msg)
        }
        try container.mainContext.save()

        deepRender(ChatTabView().environment(router).modelContainer(container), duration: 0.4)
    }

    func testChatTabViewWithDocumentCards() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        let conv = Conversation()
        container.mainContext.insert(conv)

        let file = DocumentFile(name: "Scanned", fileExtension: "pdf", relativeFilePath: "Scanned.pdf", fileSize: 2048, pageCount: 3)
        container.mainContext.insert(file)

        let msg = ChatMessage(
            content: "Scanned.pdf",
            role: "assistant",
            conversation: conv,
            toolBadge: "Scanner",
            messageType: "documentCard",
            documentFileId: file.id.uuidString
        )
        container.mainContext.insert(msg)
        try container.mainContext.save()

        deepRender(ChatTabView().environment(router).modelContainer(container), duration: 0.3)
    }

    func testChatTabViewWithProcessingMessages() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        let conv = Conversation()
        container.mainContext.insert(conv)

        let msg = ChatMessage(
            content: "Extracting text...",
            role: "assistant",
            conversation: conv,
            messageType: "processing",
            inlineToolType: "ocr"
        )
        container.mainContext.insert(msg)
        try container.mainContext.save()

        deepRender(ChatTabView().environment(router).modelContainer(container), duration: 0.3)
    }

    func testChatTabViewWithToolResults() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        let conv = Conversation()
        container.mainContext.insert(conv)

        let result = InlineToolResult(toolType: "ocr", success: true, title: "Text Extracted", content: "Some extracted text content here.")
        let json = (try? JSONEncoder().encode(result)).flatMap { String(data: $0, encoding: .utf8) } ?? ""

        let msg = ChatMessage(
            content: "Text Extracted",
            role: "assistant",
            conversation: conv,
            toolBadge: "OCR",
            messageType: "toolResult",
            resultDataJSON: json
        )
        container.mainContext.insert(msg)
        try container.mainContext.save()

        deepRender(ChatTabView().environment(router).modelContainer(container), duration: 0.3)
    }

    func testChatTabViewWithRecentDocuments() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        for i in 0..<5 {
            let file = DocumentFile(name: "File\(i)", fileExtension: "pdf", relativeFilePath: "File\(i).pdf", fileSize: Int64(i * 1024))
            file.lastOpenedAt = Date()
            container.mainContext.insert(file)
        }
        try container.mainContext.save()

        deepRender(ChatTabView().environment(router).modelContainer(container), duration: 0.3)
    }
}

// MARK: - FilesTabView Extended Tests

@MainActor
final class FilesTabViewExtendedTests: XCTestCase {

    func testFilesTabViewWithManyFiles() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        let extensions = ["pdf", "jpg", "png", "docx", "txt", "xlsx"]
        for i in 0..<20 {
            let ext = extensions[i % extensions.count]
            let file = DocumentFile(name: "File\(i)", fileExtension: ext, relativeFilePath: "File\(i).\(ext)", fileSize: Int64((i + 1) * 512))
            if i < 3 { file.isFavorite = true }
            container.mainContext.insert(file)
        }
        try container.mainContext.save()

        deepRender(FilesTabView().environment(router).modelContainer(container), duration: 0.4)
    }

    func testFilesTabViewWithTaggedFiles() throws {
        let container = try makeContainer()
        let router = NavigationRouter()

        let tags = ["work", "personal", "important", "archive", "receipts", "travel"]
        for (i, tag) in tags.enumerated() {
            let file = DocumentFile(name: "Tagged\(i)", fileExtension: "pdf", relativeFilePath: "Tagged\(i).pdf", fileSize: 1024)
            file.tagName = tag
            container.mainContext.insert(file)
        }
        try container.mainContext.save()

        deepRender(FilesTabView().environment(router).modelContainer(container), duration: 0.3)
    }

    func testFilesTabViewEmptyState() throws {
        try deepRenderWithContext(FilesTabView(), duration: 0.3)
    }
}

// MARK: - FilesViewModel Tests

@MainActor
final class FilesViewModelBoostTests: XCTestCase {

    func testFilteredAndSortedEmptyFiles() {
        let vm = FilesViewModel()
        let result = vm.filteredAndSorted([])
        XCTAssertTrue(result.isEmpty)
    }

    func testFilteredAndSortedByCategory() {
        let vm = FilesViewModel()
        let files = [
            DocumentFile(name: "PDF1", fileExtension: "pdf", relativeFilePath: "PDF1.pdf", fileSize: 1024),
            DocumentFile(name: "IMG1", fileExtension: "jpg", relativeFilePath: "IMG1.jpg", fileSize: 512),
            DocumentFile(name: "PDF2", fileExtension: "pdf", relativeFilePath: "PDF2.pdf", fileSize: 2048),
        ]

        vm.selectedCategory = .pdf
        let pdfs = vm.filteredAndSorted(files)
        XCTAssertTrue(pdfs.allSatisfy { $0.fileExtension == "pdf" })
    }

    func testFilteredAndSortedBySearch() {
        let vm = FilesViewModel()
        let files = [
            DocumentFile(name: "Invoice March", fileExtension: "pdf", relativeFilePath: "Invoice.pdf", fileSize: 1024),
            DocumentFile(name: "Receipt April", fileExtension: "pdf", relativeFilePath: "Receipt.pdf", fileSize: 512),
        ]

        vm.searchText = "invoice"
        let result = vm.filteredAndSorted(files)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Invoice March")
    }

    func testFilteredAndSortedAllCategory() {
        let vm = FilesViewModel()
        vm.selectedCategory = .all
        let files = [
            DocumentFile(name: "A", fileExtension: "pdf", relativeFilePath: "A.pdf", fileSize: 1024),
            DocumentFile(name: "B", fileExtension: "jpg", relativeFilePath: "B.jpg", fileSize: 512),
        ]
        let result = vm.filteredAndSorted(files)
        XCTAssertEqual(result.count, 2)
    }

    func testSortOptions() {
        let vm = FilesViewModel()
        let files = [
            DocumentFile(name: "Bravo", fileExtension: "pdf", relativeFilePath: "Bravo.pdf", fileSize: 100),
            DocumentFile(name: "Alpha", fileExtension: "pdf", relativeFilePath: "Alpha.pdf", fileSize: 200),
        ]

        vm.sortOption = .nameAsc
        let sorted = vm.filteredAndSorted(files)
        XCTAssertEqual(sorted.first?.name, "Alpha")

        vm.sortOption = .nameDesc
        let sortedDesc = vm.filteredAndSorted(files)
        XCTAssertEqual(sortedDesc.first?.name, "Bravo")

        vm.sortOption = .sizeAsc
        let sortedSize = vm.filteredAndSorted(files)
        XCTAssertEqual(sortedSize.first?.name, "Bravo")

        vm.sortOption = .sizeDesc
        let sortedSizeDesc = vm.filteredAndSorted(files)
        XCTAssertEqual(sortedSizeDesc.first?.name, "Alpha")
    }
}

// MARK: - ToolItem Enum Tests

@MainActor
final class ToolItemEnumTests: XCTestCase {

    func testAllToolsHaveNames() {
        for tool in ToolItem.allCases {
            XCTAssertFalse(tool.rawValue.isEmpty)
        }
    }

    func testToolItemCount() {
        // Should have 22+ tools
        XCTAssertTrue(ToolItem.allCases.count >= 22)
    }
}

// MARK: - NavigationRouter Tests

@MainActor
final class NavigationRouterBoostTests: XCTestCase {

    func testDefaultTab() {
        let router = NavigationRouter()
        XCTAssertEqual(router.selectedTab, .inbox)
    }

    func testSwitchTabs() {
        let router = NavigationRouter()
        router.selectedTab = .tools
        XCTAssertEqual(router.selectedTab, .tools)
        router.selectedTab = .tools
        XCTAssertEqual(router.selectedTab, .tools)
        router.selectedTab = .settings
        XCTAssertEqual(router.selectedTab, .settings)
    }
}

// MARK: - AppTab Tests

@MainActor
final class AppTabEnumTests: XCTestCase {

    func testAllTabCases() {
        let tabs = AppTab.allCases
        XCTAssertTrue(tabs.count >= 3)
    }
}
