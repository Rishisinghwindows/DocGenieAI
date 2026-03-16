import SwiftUI
import SwiftData
import UIKit

@MainActor
@Observable
final class ChatViewModel {
    var inputText = ""
    var isTyping = false
    var streamingContent: String = ""
    var currentConversation: Conversation?
    var pendingAttachment: PendingAttachment?
    var pendingAgenticTool: String?

    private let aiService = AIService.shared
    private let orchestrator = AgentOrchestrator.shared
    private var documentOCRContext: [String: String] = [:]

    private let quickActions: [QuickAction] = [
        QuickAction(label: "Scan", icon: "doc.viewfinder", prompt: "Scan a document", toolId: "Scanner"),
        QuickAction(label: "Merge", icon: "doc.on.doc.fill", prompt: "Merge my PDFs", toolId: "Merge PDF"),
        QuickAction(label: "Convert", icon: "arrow.triangle.2.circlepath", prompt: "Convert a file to PDF", toolId: "Doc to PDF"),
        QuickAction(label: "OCR", icon: "text.viewfinder", prompt: "Extract text from an image", toolId: "OCR Text"),
        QuickAction(label: "Compress", icon: "arrow.down.doc", prompt: "Compress a PDF", toolId: "Compress"),
        QuickAction(label: "Watermark", icon: "drop.triangle", prompt: "Add a watermark to PDF", toolId: "Watermark"),
    ]

    var actions: [QuickAction] { quickActions }
    var welcomeActions: [QuickAction] { Array(quickActions.prefix(4)) }

    func attachFile(url: URL) {
        pendingAttachment = PendingAttachment.from(url: url)
    }

    func removeAttachment() {
        pendingAttachment = nil
    }

    func startNewConversation(context: ModelContext) {
        let conversation = Conversation()
        context.insert(conversation)
        try? context.save()
        currentConversation = conversation
        documentOCRContext.removeAll()
        aiService.resetSession()
    }

    func sendMessage(context: ModelContext, allMessages: [ChatMessage] = []) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = pendingAttachment

        guard !text.isEmpty || attachment != nil else { return }

        if currentConversation == nil {
            startNewConversation(context: context)
        }

        guard let conversation = currentConversation else { return }

        // Check if orchestrator should handle this (active agent state)
        let agentState = orchestrator.getState(for: conversation.id)
        if case .idle = agentState {
            // 1. Check for multi-step pipeline ("scan and summarize", "extract and translate")
            if attachment == nil, let pipeline = orchestrator.detectPipeline(from: text) {
                let userMsg = ChatMessage(content: text, role: "user", conversation: conversation)
                context.insert(userMsg)
                conversation.updatedAt = .now
                if conversation.title == "New Chat" {
                    conversation.title = ConversationTitleGenerator.generate(from: text)
                }
                inputText = ""
                pendingAgenticTool = pipeline.name

                let stepsDesc = pipeline.steps.map { "**\($0.name)**" }.joined(separator: " → ")
                let aiMsg = ChatMessage(
                    content: "I'll run a \(pipeline.steps.count)-step pipeline: \(stepsDesc). Attach your file to begin.",
                    role: "assistant",
                    conversation: conversation,
                    toolBadge: pipeline.name
                )
                context.insert(aiMsg)
                try? context.save()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .triggerAttachFile, object: nil)
                }
                return
            }

            // 2. Check for single tool intent
            if attachment == nil, let tool = orchestrator.detectIntent(from: text) {
                let userMsg = ChatMessage(content: text, role: "user", conversation: conversation)
                context.insert(userMsg)
                conversation.updatedAt = .now
                if conversation.title == "New Chat" {
                    conversation.title = ConversationTitleGenerator.generate(from: text)
                }
                inputText = ""
                pendingAgenticTool = tool.displayName

                let response = orchestrator.process(
                    conversationId: conversation.id,
                    userMessage: text,
                    attachedFile: nil,
                    context: context
                )
                if let msg = response.message {
                    let aiMsg = ChatMessage(
                        content: msg,
                        role: "assistant",
                        conversation: conversation,
                        toolBadge: response.toolBadge,
                        actions: response.actions
                    )
                    context.insert(aiMsg)
                }
                try? context.save()
                return
            }
        } else {
            // Active orchestrator state — route through it
        }

        // Handle file attachment flow
        if let attachment {
            pendingAttachment = nil
            inputText = ""

            let userContent = text.isEmpty ? "Here's a file: \(attachment.fullFileName)" : text
            let userMessage = ChatMessage(
                content: userContent,
                role: "user",
                conversation: conversation
            )
            context.insert(userMessage)

            conversation.updatedAt = .now
            if conversation.title == "New Chat" {
                conversation.title = ConversationTitleGenerator.generate(from: userContent)
            }

            let importService = FileImportService()
            do {
                let imported = try importService.importFiles(from: [attachment.url], into: context)
                if let docFile = imported.first {
                    // Check for pending pipeline first
                    if let pendingName = pendingAgenticTool,
                       let pipeline = orchestrator.pipelines.values.first(where: { $0.name == pendingName }) {
                        executePipeline(pipeline, document: docFile, context: context)
                    } else if let pendingTool = pendingAgenticTool {
                        autoExecutePendingTool(pendingTool, document: docFile, context: context)
                    } else {
                        handleAttachedDocument(documentId: docFile.id.uuidString, document: docFile, context: context)
                    }
                }
            } catch {
                let errorMsg = ChatMessage(
                    content: "Failed to import the file. Please try again.",
                    role: "assistant",
                    conversation: conversation
                )
                context.insert(errorMsg)
                try? context.save()
            }
            return
        }

        let userMessage = ChatMessage(
            content: text,
            role: "user",
            conversation: conversation
        )
        context.insert(userMessage)

        conversation.updatedAt = .now
        if conversation.title == "New Chat" {
            conversation.title = ConversationTitleGenerator.generate(from: text)
        }

        inputText = ""
        try? context.save()

        let history = messagesForCurrentConversation(allMessages: allMessages)

        // Build enriched input with document OCR context if available
        var enrichedInput = text
        if !documentOCRContext.isEmpty {
            let conversationMessages = messagesForCurrentConversation(allMessages: allMessages)
            if let recentDocCard = conversationMessages.last(where: { $0.messageType == "documentCard" && !$0.documentFileId.isEmpty }),
               let ocrText = documentOCRContext[recentDocCard.documentFileId] {
                let truncatedOCR = String(ocrText.prefix(2000))
                enrichedInput = """
                [Document context from scanned/attached file]
                The following is text extracted from the user's document. Answer their question directly from this text. If they mention a language name, they want translation — do NOT suggest file conversion. If they ask about amounts or details, find them in the text.
                ---
                \(truncatedOCR)
                ---

                User question: \(text)
                """
            }
        }

        // Fetch memories for context
        let memories = MemoryService.shared.fetchMemories(context: context)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isTyping = true
            self.streamingContent = ""

            nonisolated(unsafe) let placeholder = ChatMessage(
                content: "",
                role: "assistant",
                conversation: conversation
            )
            context.insert(placeholder)
            try? context.save()

            do {
                let result: AIResponse
                if self.aiService.supportsStreaming {
                    result = try await self.aiService.streamResponse(
                        for: enrichedInput,
                        conversationHistory: history,
                        memories: memories
                    ) { [weak self] partialText in
                        self?.streamingContent = partialText
                        placeholder.content = partialText
                    }
                } else {
                    result = try await self.aiService.generateResponse(
                        for: enrichedInput,
                        conversationHistory: history,
                        memories: memories
                    )
                }

                // Finalize the message
                placeholder.content = result.text
                placeholder.toolBadge = result.toolBadge
                if !result.actions.isEmpty,
                   let data = try? JSONEncoder().encode(result.actions) {
                    placeholder.actionsJSON = String(data: data, encoding: .utf8)
                }
                try? context.save()

                // Extract and save memories from this interaction
                let newMemories = MemoryService.shared.extractMemories(
                    userMessage: text,
                    aiResponse: result.text
                )
                for memory in newMemories {
                    MemoryService.shared.saveMemory(memory, context: context)
                }
            } catch {
                placeholder.content = "Sorry, I encountered an error. Try asking me about scanning, merging, or converting documents."
                try? context.save()
            }

            self.streamingContent = ""
            self.isTyping = false
        }
    }

    func sendQuickAction(_ action: QuickAction, context: ModelContext) {
        inputText = action.prompt
        sendMessage(context: context)
    }

    // MARK: - Agentic Tool Flow

    private static let agenticToolPrompts: [String: (greeting: String, instruction: String)] = [
        "Merge PDF": ("Merge my PDFs", "Select the PDFs to merge."),
        "Compress": ("Compress a PDF", "Select the PDF to compress."),
        "OCR Text": ("Extract text", "Select a PDF or image for OCR."),
        "Split PDF": ("Split a PDF", "Select the PDF to split."),
        "Lock PDF": ("Lock a PDF", "Select the PDF to password-protect."),
        "Unlock PDF": ("Unlock a PDF", "Select the locked PDF."),
        "Watermark": ("Add watermark", "Select the PDF to watermark."),
        "Image to PDF": ("Images to PDF", "Select the images to convert."),
        "Sign PDF": ("Sign a PDF", "Select the PDF to sign."),
        "Doc to PDF": ("Convert to PDF", "Select the document to convert."),
        "PDF to Image": ("PDF to images", "Select the PDF to export as images."),
        "PDF to Text": ("Extract PDF text", "Select the PDF to extract text from."),
        "Translate PDF": ("Translate document", "Select the document to translate."),
        "Summarize PDF": ("Summarize document", "Select the document to summarize."),
        "Ask PDF": ("Ask about document", "Select the document to ask about."),
        "Rotate PDF": ("Rotate PDF pages", "Select the PDF to rotate."),
        "Reorder Pages": ("Reorder PDF pages", "Select the PDF to reorder."),
        "Page Numbers": ("Add page numbers", "Select the PDF to number."),
        "Crop PDF": ("Crop PDF margins", "Select the PDF to crop."),
        "PDF Metadata": ("Edit PDF info", "Select the PDF to view metadata."),
        "Email PDF": ("Email a PDF", "Select the PDF to email."),
    ]

    func startAgenticToolFlow(toolId: String, context: ModelContext) {
        guard let prompts = Self.agenticToolPrompts[toolId] else {
            // Fall back to sending as a regular message
            inputText = "I want to use \(toolId)"
            sendMessage(context: context)
            return
        }

        // Create conversation if needed
        if currentConversation == nil {
            startNewConversation(context: context)
        }
        guard let conversation = currentConversation else { return }

        // Track the pending tool
        pendingAgenticTool = toolId

        // User message
        let userMsg = ChatMessage(content: prompts.greeting, role: "user", conversation: conversation)
        context.insert(userMsg)

        conversation.updatedAt = .now
        if conversation.title == "New Chat" {
            conversation.title = ConversationTitleGenerator.generate(from: prompts.greeting)
        }

        // Brief AI response
        let aiMsg = ChatMessage(
            content: prompts.instruction,
            role: "assistant",
            conversation: conversation,
            toolBadge: toolId
        )
        context.insert(aiMsg)
        try? context.save()

        // Auto-open file picker immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .triggerAttachFile, object: nil)
        }
    }

    // MARK: - Pipeline Execution (Multi-Step)

    private func executePipeline(_ pipeline: AgentOrchestrator.Pipeline, document: DocumentFile, context: ModelContext) {
        guard let conversation = currentConversation else { return }
        pendingAgenticTool = nil

        Task { @MainActor [weak self] in
            guard let self else { return }

            for (index, step) in pipeline.steps.enumerated() {
                // Show step progress
                let stepMsg = ChatMessage(
                    content: "Step \(index + 1)/\(pipeline.steps.count): **\(step.name)**...",
                    role: "assistant",
                    conversation: conversation,
                    toolBadge: pipeline.name,
                    messageType: "processing"
                )
                context.insert(stepMsg)
                try? context.save()

                // Execute step
                let result = await self.inlineToolExecutor.execute(
                    toolType: step.toolType,
                    documentFile: document,
                    context: context
                )

                // Remove processing message
                context.delete(stepMsg)

                // Show step result
                let resultMsg = ChatMessage(
                    content: "**\(step.name)**: \(result.success ? result.content : "Failed — \(result.content)")",
                    role: "assistant",
                    conversation: conversation,
                    toolBadge: result.success ? step.name : "Error",
                    messageType: "toolResult"
                )
                resultMsg.resultDataJSON = (try? String(data: JSONEncoder().encode(result), encoding: .utf8)) ?? ""
                context.insert(resultMsg)
                try? context.save()

                // Stop pipeline on error
                if !result.success {
                    let errorMsg = ChatMessage(
                        content: "Pipeline stopped at step \(index + 1). You can retry or try a different approach.",
                        role: "assistant",
                        conversation: conversation
                    )
                    context.insert(errorMsg)
                    try? context.save()
                    HapticManager.error()
                    return
                }
            }

            // Pipeline complete
            let doneMsg = ChatMessage(
                content: "Pipeline **\(pipeline.name)** completed successfully! All \(pipeline.steps.count) steps done.",
                role: "assistant",
                conversation: conversation,
                toolBadge: "Complete"
            )
            context.insert(doneMsg)
            try? context.save()
            HapticManager.success()
        }
    }

    // MARK: - Auto-Execute Pending Tool

    private func autoExecutePendingTool(_ toolId: String, document: DocumentFile, context: ModelContext) {
        guard let conversation = currentConversation else { return }
        let documentId = document.id.uuidString

        // Map toolId to inline tool type — ALL tools that can auto-execute
        let inlineToolMap: [String: String] = [
            "Compress": "compress",
            "Watermark": "watermark",
            "OCR Text": "ocr",
            "Summarize PDF": "summarize",
            "Page Numbers": "page_numbers",
            "Rotate PDF": "rotate",
            "PDF to Text": "pdf_to_text",
            "PDF to Image": "pdf_to_image",
            "Doc to PDF": "doc_to_pdf",
        ]

        if let inlineType = inlineToolMap[toolId] {
            // Show processing message
            let processingMsg = ChatMessage(
                content: "Processing **\(toolId)** on \(document.fullFileName)...",
                role: "assistant",
                conversation: conversation,
                toolBadge: toolId,
                messageType: "processing"
            )
            context.insert(processingMsg)
            try? context.save()

            // Execute inline
            pendingAgenticTool = nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                let result = await self.inlineToolExecutor.execute(
                    toolType: inlineType,
                    documentFile: document,
                    context: context
                )

                // Remove processing message
                context.delete(processingMsg)

                // Show result
                let resultMsg = ChatMessage(
                    content: result.content,
                    role: "assistant",
                    conversation: conversation,
                    toolBadge: toolId,
                    messageType: "toolResult"
                )
                resultMsg.resultDataJSON = (try? String(data: JSONEncoder().encode(result), encoding: .utf8)) ?? ""

                // Add follow-up actions
                var followUpActions: [ChatAction] = []
                if let outputId = result.outputFileId {
                    followUpActions.append(ChatAction(label: "Open", icon: "doc", actionType: .openFile, fileId: outputId))
                    followUpActions.append(ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: outputId))
                }
                // Chain suggestions from orchestrator
                if let agentTool = AgentOrchestrator.AgentTool.from(toolId: toolId) {
                    let chainActions = self.orchestrator.onToolComplete(
                        conversationId: conversation.id,
                        tool: agentTool,
                        result: result
                    )
                    followUpActions.append(contentsOf: chainActions)
                }
                if !followUpActions.isEmpty,
                   let data = try? JSONEncoder().encode(followUpActions) {
                    resultMsg.actionsJSON = String(data: data, encoding: .utf8)
                }

                context.insert(resultMsg)
                try? context.save()
                HapticManager.success()
            }
        } else {
            // Tools that need a sheet (Merge, Split, Lock, Sign, etc.)
            // Show the document card and let user proceed
            handleAttachedDocument(documentId: documentId, document: document, context: context)
            pendingAgenticTool = nil
        }
    }

    func handleAction(_ action: ChatAction, coordinator: ChatToolCoordinator, router: NavigationRouter, context: ModelContext) {
        switch action.actionType {
        case .openTool:
            if let toolId = action.toolId {
                if toolId == "Scanner" {
                    if let tool = coordinator.toolForId(toolId) {
                        coordinator.openTool(tool)
                    }
                } else if Self.agenticToolPrompts[toolId] != nil {
                    startAgenticToolFlow(toolId: toolId, context: context)
                } else if let tool = coordinator.toolForId(toolId) {
                    coordinator.openTool(tool)
                }
            }
        case .navigateTab:
            if let tabId = action.tabId {
                switch tabId {
                case "tools": router.selectedTab = .tools
                case "files", "settings": router.selectedTab = .settings
                default: break
                }
            }
        case .openFile:
            if let fileId = action.fileId,
               let targetUUID = UUID(uuidString: fileId) {
                var descriptor = FetchDescriptor<DocumentFile>(predicate: #Predicate { $0.id == targetUUID })
                descriptor.fetchLimit = 1
                if let doc = (try? context.fetch(descriptor))?.first,
                   let url = doc.fileURL {
                    ShareService.shared.share(fileURL: url)
                }
            }
        case .showResult:
            break
        case .executeInline:
            if let toolType = action.payload, let fileId = action.fileId {
                executeInlineAction(toolType: toolType, documentFileId: fileId, context: context)
            }
        case .copyText:
            if let text = action.payload {
                UIPasteboard.general.string = text
            }
        case .shareFile:
            if let fileId = action.fileId,
               let targetUUID = UUID(uuidString: fileId) {
                var descriptor = FetchDescriptor<DocumentFile>(predicate: #Predicate { $0.id == targetUUID })
                descriptor.fetchLimit = 1
                if let doc = (try? context.fetch(descriptor))?.first,
                   let url = doc.fileURL {
                    ShareService.shared.share(fileURL: url)
                }
            }
        case .attachFile:
            // Handled in ChatTabView — triggers the attachment confirmation dialog
            NotificationCenter.default.post(name: .triggerAttachFile, object: nil)
        }
    }

    func messagesForCurrentConversation(allMessages: [ChatMessage]) -> [ChatMessage] {
        guard let conversation = currentConversation else { return [] }
        return allMessages
            .filter { $0.conversationId == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - File Attachment

    func handleAttachedDocument(documentId: String, document: DocumentFile, context: ModelContext) {
        guard let conversation = currentConversation else { return }

        let actions = [
            ChatAction(label: "OCR", icon: "text.viewfinder", actionType: .executeInline, fileId: documentId, payload: "ocr"),
            ChatAction(label: "Summary", icon: "doc.text.magnifyingglass", actionType: .executeInline, fileId: documentId, payload: "summarize"),
            ChatAction(label: "Formal", icon: "textformat", actionType: .executeInline, fileId: documentId, payload: "rewrite_formal"),
            ChatAction(label: "Casual", icon: "text.bubble", actionType: .executeInline, fileId: documentId, payload: "rewrite_casual"),
            ChatAction(label: "Grammar", icon: "checkmark.circle", actionType: .executeInline, fileId: documentId, payload: "fix_grammar"),
            ChatAction(label: "Bullets", icon: "list.bullet", actionType: .executeInline, fileId: documentId, payload: "bullet_points"),
            ChatAction(label: "Expand", icon: "arrow.up.left.and.arrow.down.right", actionType: .executeInline, fileId: documentId, payload: "expand"),
            ChatAction(label: "Compress", icon: "arrow.down.doc", actionType: .executeInline, fileId: documentId, payload: "compress"),
            ChatAction(label: "Watermark", icon: "drop.triangle", actionType: .executeInline, fileId: documentId, payload: "watermark"),
            ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: documentId),
        ]

        let cardMessage = ChatMessage(
            content: "I received \(document.fullFileName). What would you like to do with it?",
            role: "assistant",
            conversation: conversation,
            toolBadge: "File Import",
            actions: actions,
            messageType: "documentCard",
            documentFileId: documentId
        )
        context.insert(cardMessage)
        try? context.save()

        // Background OCR → auto-summary for attached files too
        if let fileURL = document.fileURL {
            let cardMessageId = cardMessage.id
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.runBackgroundOCR(
                    documentId: documentId,
                    cardMessageId: cardMessageId,
                    fileURL: fileURL,
                    context: context
                )
            }
        }
    }

    // MARK: - Inline Scan-to-Chat

    private let inlineToolExecutor = InlineChatToolExecutor.shared

    func handleScannedImages(_ images: [UIImage], context: ModelContext) {
        guard !images.isEmpty else { return }

        HapticManager.success()

        if currentConversation == nil {
            let autoName = "Scan \(Date.now.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
            let conversation = Conversation(title: autoName)
            context.insert(conversation)
            do {
                try context.save()
            } catch {
                // If save fails, try to continue — SwiftData may auto-save
            }
            currentConversation = conversation
            aiService.resetSession()
        }

        guard let conversation = currentConversation else { return }

        let pages = images.map { ScannedPage(image: $0) }
        let autoFileName = "Scan \(Date.now.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"

        do {
            let result = try ScannerService.shared.saveScanAsPDF(pages: pages, fileName: autoFileName)
            let metadata = FileMetadataService.shared.extractMetadata(from: result.url)

            let docFile = DocumentFile(
                name: (result.url.lastPathComponent as NSString).deletingPathExtension,
                fileExtension: "pdf",
                relativeFilePath: result.relativePath,
                fileSize: metadata.fileSize,
                pageCount: pages.count
            )
            context.insert(docFile)
            try context.save()

            let documentId = docFile.id.uuidString

            // Immediate document card with basic actions
            let basicActions = [
                ChatAction(label: "Extract Text", icon: "text.viewfinder", actionType: .executeInline, fileId: documentId, payload: "ocr"),
                ChatAction(label: "Summarize", icon: "doc.text.magnifyingglass", actionType: .executeInline, fileId: documentId, payload: "summarize"),
                ChatAction(label: "Compress PDF", icon: "arrow.down.doc", actionType: .executeInline, fileId: documentId, payload: "compress"),
                ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: documentId),
            ]

            let pageLabel = pages.count == 1 ? "page" : "pages"
            let cardMessage = ChatMessage(
                content: "\(pages.count) \(pageLabel) scanned and saved as \(docFile.fullFileName)",
                role: "assistant",
                conversation: conversation,
                toolBadge: "Scanner",
                actions: basicActions,
                messageType: "documentCard",
                documentFileId: documentId
            )
            context.insert(cardMessage)
            do {
                try context.save()
            } catch {
                // SwiftData may auto-save; continue
            }

            // Background OCR for smart action suggestions
            let cardMessageId = cardMessage.id
            let fileURL = result.url
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.runBackgroundOCR(
                    documentId: documentId,
                    cardMessageId: cardMessageId,
                    fileURL: fileURL,
                    context: context
                )
            }

        } catch {
            let errorMsg = ChatMessage(
                content: "Failed to save scanned document. Please try again.",
                role: "assistant",
                conversation: conversation
            )
            context.insert(errorMsg)
            try? context.save()
            HapticManager.error()
        }
    }

    private func runBackgroundOCR(
        documentId: String,
        cardMessageId: UUID,
        fileURL: URL,
        context: ModelContext
    ) async {
        guard let conversation = currentConversation else { return }

        do {
            let ocrText = try await OCRService.shared.extractText(from: fileURL)

            // Store for AI follow-up questions (LRU eviction — remove oldest when at capacity)
            if documentOCRContext.count >= 20, let oldestKey = documentOCRContext.keys.first {
                documentOCRContext.removeValue(forKey: oldestKey)
            }
            documentOCRContext[documentId] = ocrText

            // Classify content
            let contentType = ScanContentType.classify(ocrText: ocrText)

            // Build smart actions
            var smartActions: [ChatAction] = contentType.suggestedActions.map { suggestion in
                ChatAction(
                    label: suggestion.label,
                    icon: suggestion.icon,
                    actionType: .executeInline,
                    fileId: documentId,
                    payload: suggestion.toolType
                )
            }
            smartActions.append(
                ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: documentId)
            )

            // Update card message actions in-place
            var msgDescriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.id == cardMessageId })
            msgDescriptor.fetchLimit = 1
            if let cardMsg = (try? context.fetch(msgDescriptor))?.first {
                if let data = try? JSONEncoder().encode(smartActions) {
                    cardMsg.actionsJSON = String(data: data, encoding: .utf8)
                }
            }

            // Auto-generate summary — use structured parsers for receipts/cards
            let autoSummary: String
            switch contentType {
            case .receipt:
                let receipt = ScanContentType.parseReceipt(ocrText: ocrText)
                autoSummary = receipt.formattedSummary
            case .businessCard:
                let card = ScanContentType.parseBusinessCard(ocrText: ocrText)
                autoSummary = card.formattedSummary
            default:
                autoSummary = contentType.generateAutoSummary(ocrText: ocrText)
            }

            let summaryMessage = ChatMessage(
                content: autoSummary,
                role: "assistant",
                conversation: conversation,
                toolBadge: contentType.displayLabel,
                actions: smartActions
            )
            context.insert(summaryMessage)

            // Store OCR text for search
            let targetUUID = UUID(uuidString: documentId) ?? UUID()
            var docDescriptor = FetchDescriptor<DocumentFile>(predicate: #Predicate { $0.id == targetUUID })
            docDescriptor.fetchLimit = 1
            if let docFile = (try? context.fetch(docDescriptor))?.first {
                docFile.ocrTextCache = String(ocrText.prefix(5000))
            }
            try? context.save()

        } catch {
            // OCR failed — post a fallback message with basic actions
            let fallbackActions = [
                ChatAction(label: "Extract Text", icon: "text.viewfinder", actionType: .executeInline, fileId: documentId, payload: "ocr"),
                ChatAction(label: "Compress PDF", icon: "arrow.down.doc", actionType: .executeInline, fileId: documentId, payload: "compress"),
                ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: documentId),
            ]
            let fallbackMsg = ChatMessage(
                content: "Document saved. What would you like to do with it?",
                role: "assistant",
                conversation: conversation,
                actions: fallbackActions
            )
            context.insert(fallbackMsg)
            try? context.save()
        }
    }

    func executeInlineAction(toolType: String, documentFileId: String, context: ModelContext) {
        guard let conversation = currentConversation else { return }

        // Find the document
        guard let targetUUID = UUID(uuidString: documentFileId) else { return }
        var docDescriptor = FetchDescriptor<DocumentFile>(predicate: #Predicate { $0.id == targetUUID })
        docDescriptor.fetchLimit = 1
        guard let doc = (try? context.fetch(docDescriptor))?.first else { return }

        // Insert processing message
        let processingMsg = ChatMessage(
            content: processingText(for: toolType),
            role: "assistant",
            conversation: conversation,
            messageType: "processing",
            documentFileId: documentFileId,
            inlineToolType: toolType
        )
        context.insert(processingMsg)
        try? context.save()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.inlineToolExecutor.execute(toolType: toolType, documentFile: doc, context: context)

            // Update processing message to result
            processingMsg.content = result.content
            processingMsg.messageType = "toolResult"
            if let data = try? JSONEncoder().encode(result) {
                processingMsg.resultDataJSON = String(data: data, encoding: .utf8) ?? ""
            }
            try? context.save()

            // For tools that produce output files (compress/watermark), show a document card + auto-summary
            if result.success, let outputId = result.outputFileId, let outputUUID = UUID(uuidString: outputId) {
                var outputDescriptor = FetchDescriptor<DocumentFile>(predicate: #Predicate { $0.id == outputUUID })
                outputDescriptor.fetchLimit = 1
                if let outputDoc = (try? context.fetch(outputDescriptor))?.first {
                    self.handleAttachedDocument(documentId: outputId, document: outputDoc, context: context)
                    return
                }
            }

            // For text-only results (OCR/summarize), add follow-up actions
            let followUps = self.buildFollowUpActions(toolType: toolType, result: result, documentFileId: documentFileId)
            if !followUps.isEmpty {
                let followUpMsg = ChatMessage(
                    content: result.success ? "What would you like to do next?" : "Would you like to try something else?",
                    role: "assistant",
                    conversation: conversation,
                    actions: followUps
                )
                context.insert(followUpMsg)
                try? context.save()
            }
        }
    }

    // MARK: - Tools Tab → Chat Integration

    /// Called when a PDF tool or converter finishes and produces a new document
    func handleToolOutput(documentId: String, toolName: String, context: ModelContext) {
        // Ensure we have a conversation
        if currentConversation == nil {
            startNewConversation(context: context)
        }
        guard let conversation = currentConversation else { return }

        // Find the document
        guard let targetUUID = UUID(uuidString: documentId) else { return }
        var docDescriptor = FetchDescriptor<DocumentFile>(predicate: #Predicate { $0.id == targetUUID })
        docDescriptor.fetchLimit = 1
        guard let doc = (try? context.fetch(docDescriptor))?.first else { return }

        // Create document card
        let actions = [
            ChatAction(label: "Extract Text", icon: "text.viewfinder", actionType: .executeInline, fileId: documentId, payload: "ocr"),
            ChatAction(label: "Summarize", icon: "doc.text.magnifyingglass", actionType: .executeInline, fileId: documentId, payload: "summarize"),
            ChatAction(label: "Compress PDF", icon: "arrow.down.doc", actionType: .executeInline, fileId: documentId, payload: "compress"),
            ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: documentId),
        ]

        let cardMessage = ChatMessage(
            content: "\(toolName) complete — \(doc.fullFileName) is ready.",
            role: "assistant",
            conversation: conversation,
            toolBadge: toolName,
            actions: actions,
            messageType: "documentCard",
            documentFileId: documentId
        )
        context.insert(cardMessage)
        try? context.save()

        // Background OCR → auto-summary
        if let fileURL = doc.fileURL {
            let cardMessageId = cardMessage.id
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.runBackgroundOCR(
                    documentId: documentId,
                    cardMessageId: cardMessageId,
                    fileURL: fileURL,
                    context: context
                )
            }
        }
    }

    private func processingText(for toolType: String) -> String {
        switch toolType {
        case "ocr": return "Extracting text from your document..."
        case "summarize": return "Generating summary..."
        case "compress": return "Compressing your PDF..."
        case "watermark": return "Adding watermark..."
        default: return "Processing..."
        }
    }

    private func buildFollowUpActions(toolType: String, result: InlineToolResult, documentFileId: String) -> [ChatAction] {
        guard result.success else { return [] }

        switch toolType {
        case "ocr":
            return [
                ChatAction(label: "Copy Text", icon: "doc.on.doc", actionType: .copyText, payload: result.content),
                ChatAction(label: "Summarize", icon: "doc.text.magnifyingglass", actionType: .executeInline, fileId: documentFileId, payload: "summarize"),
                ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: documentFileId),
            ]
        case "summarize":
            return [
                ChatAction(label: "Copy Summary", icon: "doc.on.doc", actionType: .copyText, payload: result.content),
                ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: documentFileId),
            ]
        case "compress":
            var actions: [ChatAction] = []
            if let outputId = result.outputFileId {
                actions.append(ChatAction(label: "Open File", icon: "doc", actionType: .openFile, fileId: outputId))
            }
            actions.append(ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: result.outputFileId ?? documentFileId))
            return actions
        case "watermark":
            var actions: [ChatAction] = []
            if let outputId = result.outputFileId {
                actions.append(ChatAction(label: "Open File", icon: "doc", actionType: .openFile, fileId: outputId))
            }
            actions.append(ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: result.outputFileId ?? documentFileId))
            return actions
        default:
            return []
        }
    }
}

struct QuickAction: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let prompt: String
    var toolId: String?
}

// MARK: - Smart Title Generator

enum ConversationTitleGenerator {
    private static let fillerPrefixes = [
        "hey ", "hi ", "hello ", "please ", "can you ", "could you ",
        "i want to ", "i need to ", "i'd like to ", "help me ",
    ]

    static func generate(from message: String) -> String {
        var text = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip file attachment prefix
        if text.hasPrefix("Here's a file: ") {
            let fileName = String(text.dropFirst("Here's a file: ".count))
            return truncateAtWord(fileName, limit: 35)
        }

        // Strip filler prefixes
        let lower = text.lowercased()
        for prefix in fillerPrefixes {
            if lower.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        // Capitalize first letter
        if let first = text.first {
            text = first.uppercased() + text.dropFirst()
        }

        return truncateAtWord(text, limit: 35)
    }

    private static func truncateAtWord(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let truncated = String(text.prefix(limit))
        // Find last space to avoid cutting mid-word
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "…"
        }
        return truncated + "…"
    }
}
