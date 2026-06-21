import SwiftUI
import SwiftData
import TipKit
import PhotosUI

struct ChatTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    // NOTE: @Query in iOS 17 has no fetchLimit param — these load full collections.
    // OK in practice (typical chat history fits comfortably in memory; conversations
    // are fewer than messages). When the deployment target moves to iOS 18+ replace
    // with @Query(filter:sort:fetchLimit:) to bound large libraries.
    @Query(sort: \ChatMessage.timestamp) private var allMessages: [ChatMessage]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \DocumentFile.importedAt, order: .reverse) private var allDocuments: [DocumentFile]
    @State private var viewModel = ChatViewModel()
    @State private var coordinator = ChatToolCoordinator()
    @State private var showHistory = false
    @State private var speechService = SpeechRecognitionService()
    @State private var showAttachmentMenu = false
    @State private var showDocumentPicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []

    // Tutorial
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @State private var showTutorial = false
    @State private var tutorialStep = 0
    @State private var spotlightAnchors: [TutorialTarget: CGRect] = [:]

    private var messages: [ChatMessage] {
        viewModel.messagesForCurrentConversation(allMessages: allMessages)
    }

    private var recentDocuments: [DocumentFile] {
        Array(
            allDocuments
                .filter { $0.lastOpenedAt != nil }
                .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
                .prefix(3)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    AIAvailabilityBanner()

                    if messages.isEmpty && !viewModel.isTyping {
                        welcomeView
                    } else {
                        messageList
                    }

                    if viewModel.isTyping && viewModel.streamingContent.isEmpty {
                        HStack(spacing: AppSpacing.sm) {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if !messages.isEmpty || viewModel.isTyping {
                        QuickActionsView(actions: viewModel.actions) { action in
                            if let toolId = action.toolId {
                                if toolId == "Scanner" {
                                    if let tool = coordinator.toolForId(toolId) {
                                        coordinator.openTool(tool)
                                    }
                                } else {
                                    viewModel.startAgenticToolFlow(toolId: toolId, context: modelContext)
                                }
                            } else {
                                viewModel.sendQuickAction(action, context: modelContext)
                            }
                        }
                        .padding(.vertical, AppSpacing.xs)

                        if !recentDocuments.isEmpty && viewModel.pendingAttachment == nil {
                            RecentFilesStrip(files: recentDocuments) { file in
                                if let url = file.fileURL {
                                    viewModel.attachFile(url: url)
                                }
                            }
                        }
                    }

                    Divider().background(Color.appBorder)

                    ChatInputBar(
                        text: $viewModel.inputText,
                        isTyping: viewModel.isTyping,
                        pendingAttachment: viewModel.pendingAttachment,
                        isRecording: speechService.isRecording,
                        audioLevel: speechService.audioLevel,
                        onSend: { viewModel.sendMessage(context: modelContext, allMessages: allMessages) },
                        onAttachTapped: { showAttachmentMenu = true },
                        onVoiceToggle: { handleVoiceToggle() },
                        onRemoveAttachment: { viewModel.removeAttachment() },
                        onSlashCommand: { cmd in handleSlashCommand(cmd) }
                    )
                    .spotlightAnchor(.chatInput)
                }

                // Floating Scan FAB — visible only on welcome screen
                if messages.isEmpty && !viewModel.isTyping {
                    Button {
                        HapticManager.medium()
                        coordinator.showScanner = true
                    } label: {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.appPrimary, Color.appAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: Circle()
                            )
                            .shadow(color: Color.appPrimary.opacity(0.4), radius: 12, y: 6)
                    }
                    .padding(.trailing, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .background(Color.appBGDark)
            .dropDestination(for: URL.self) { urls, _ in
                if let url = urls.first {
                    viewModel.attachFile(url: url)
                }
                return !urls.isEmpty
            }
            .onDisappear { cleanupTempPhotos() }
            .navigationTitle(messages.isEmpty && !viewModel.isTyping ? "" : "Olea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(messages.isEmpty && !viewModel.isTyping ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.light()
                        viewModel.currentConversation = nil
                    } label: {
                        Image(systemName: "plus.bubble")
                            .foregroundStyle(Color.appPrimary)
                    }
                    .spotlightAnchor(.menuButton)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.light()
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(Color.appPrimary)
                    }
                    .spotlightAnchor(.toolsButton)
                }
            }
            .sheet(isPresented: $showHistory) {
                ChatHistoryView(
                    conversations: conversations,
                    onSelect: { conversation in
                        viewModel.currentConversation = conversation
                        showHistory = false
                    },
                    onDelete: { conversation in
                        deleteConversation(conversation)
                    }
                )
                .presentationCornerRadius(24)
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $coordinator.activeTool) { tool in
                toolSheet(for: tool)
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $coordinator.gatedTool) { tool in
                RewardedAdGateSheet(
                    toolName: tool.rawValue,
                    toolIcon: tool.systemImage,
                    onUnlock: { coordinator.unlockGatedTool(tool) },
                    onCancel: { coordinator.gatedTool = nil }
                )
            }
            .fullScreenCover(isPresented: $coordinator.showScanner) {
                if DocumentCameraView.isAvailable {
                    DocumentCameraView(
                        onScanComplete: { images in
                            coordinator.showScanner = false
                            if !images.isEmpty {
                                let captured = images
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    viewModel.handleScannedImages(captured, context: modelContext)
                                }
                            }
                        },
                        onCancel: { coordinator.showScanner = false }
                    )
                    .ignoresSafeArea()
                } else {
                    VStack(spacing: AppSpacing.md) {
                        EmptyStateView(
                            icon: "camera.badge.exclamationmark",
                            title: "Camera Not Available",
                            message: "Document scanning requires a device with a camera."
                        )
                        Button("Dismiss") { coordinator.showScanner = false }
                            .foregroundStyle(Color.appPrimary)
                    }
                    .background(Color.appBGDark)
                }
            }
            .confirmationDialog("Attach", isPresented: $showAttachmentMenu, titleVisibility: .hidden) {
                Button {
                    // Delay camera launch until confirmationDialog finishes dismissing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        coordinator.showScanner = true
                    }
                } label: {
                    Label("Camera Scan", systemImage: "doc.viewfinder")
                }
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Browse Files", systemImage: "folder")
                }
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView(
                    allowsMultipleSelection: false,
                    onPick: { urls in
                        if let url = urls.first {
                            viewModel.attachFile(url: url)
                        }
                    }
                )
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 1, matching: .images)
            .onChange(of: selectedPhotos) { _, newValue in
                handlePhotoSelection(newValue)
            }
            .onChange(of: speechService.transcribedText) { _, newValue in
                if !newValue.isEmpty {
                    viewModel.inputText = newValue
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .triggerAttachFile)) { _ in
                showAttachmentMenu = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .toolDidProduceDocument)) { notification in
                guard let userInfo = notification.userInfo,
                      let documentId = userInfo["documentId"] as? String,
                      let toolName = userInfo["toolName"] as? String else { return }
                viewModel.handleToolOutput(documentId: documentId, toolName: toolName, context: modelContext)
            }
            .onPreferenceChange(SpotlightAnchorKey.self) { anchors in
                for anchor in anchors {
                    spotlightAnchors[anchor.target] = anchor.frame
                }
            }
            .overlay {
                if showTutorial {
                    SpotlightOverlayView(
                        currentStep: $tutorialStep,
                        isShowing: $showTutorial,
                        anchors: spotlightAnchors
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onChange(of: showTutorial) { _, showing in
                        if !showing {
                            hasCompletedTutorial = true
                        }
                    }
                }
            }
            .task {
                if !hasCompletedTutorial {
                    try? await Task.sleep(for: .seconds(1.0))
                    withAnimation { showTutorial = true }
                }
            }
        }
    }

    // MARK: - Welcome View
    private var welcomeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 0) {
            // Top bar — minimal, like ChatGPT
            HStack {
                Button {
                    HapticManager.light()
                    showHistory = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.appTextMuted)
                        .frame(width: 40, height: 40)
                }

                Spacer()

                Spacer()

                Button {
                    HapticManager.light()
                    viewModel.currentConversation = nil
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.appTextMuted)
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)

            ScrollView {
                VStack(spacing: 0) {
                    // Animated logo
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Color.appPrimary)
                        .frame(width: 64, height: 64)
                        .background(Color.appPrimary.opacity(0.1), in: Circle())
                        .symbolEffect(.pulse, options: .repeating)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, 24)
                    .popoverTip(ChatWelcomeTip())

                    // Greeting
                    Text(welcomeGreeting)
                        .font(.appH1)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appPrimary, Color.appAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )


                    // 2x2 suggestion grid
                    let gridColumns = [
                        GridItem(.flexible(), spacing: AppSpacing.md),
                        GridItem(.flexible(), spacing: AppSpacing.md)
                    ]

                    LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                        ForEach(Array(viewModel.welcomeActions.enumerated()), id: \.element.id) { index, action in
                            WelcomeSuggestionCard(action: action) {
                                HapticManager.light()
                                if let toolId = action.toolId {
                                    if toolId == "Scanner" {
                                        // Scanner needs camera — open directly
                                        if let tool = coordinator.toolForId(toolId) {
                                            coordinator.openTool(tool)
                                        }
                                    } else {
                                        // All other tools → agentic chat flow
                                        viewModel.startAgenticToolFlow(toolId: toolId, context: modelContext)
                                    }
                                } else {
                                    viewModel.sendQuickAction(action, context: modelContext)
                                }
                            }
                            .staggeredAppear(index: index)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.xxl)
                    .spotlightAnchor(.suggestionCards)

                    Spacer(minLength: AppSpacing.sm)
                }
            }
            .scrollIndicators(.hidden)
        }
        .task {
            await ChatWelcomeTip.chatTabVisited.donate()
        }
    }

    // MARK: - Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.messageBubble) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if shouldShowTimestamp(for: index) {
                            Text(message.timestamp.formatted(.dateTime.hour().minute()))
                                .font(.appMicro)
                                .foregroundStyle(Color.appTextDim)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, AppSpacing.xs)
                        }

                        ChatBubbleView(message: message) { action in
                            viewModel.handleAction(action, coordinator: coordinator, router: router, context: modelContext)
                        }
                        .id(message.id)
                        .staggeredAppear(index: index)
                    }
                }
                .padding(AppSpacing.md)
            }
            .onChange(of: messages.count) { _, _ in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.streamingContent) { _, _ in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Tool Sheets
    @ViewBuilder
    private func toolSheet(for tool: ToolItem) -> some View {
        switch tool {
        case .mergePDF: MergePDFView()
        case .splitPDF: SplitPDFView()
        case .compressPDF: CompressPDFView()
        case .lockPDF: LockPDFView()
        case .unlockPDF: UnlockPDFView()
        case .extractPages: ExtractPagesPDFView()
        case .rotatePDF: RotatePDFView()
        case .reorderPDF: ReorderPDFView()
        case .pageNumbers: PageNumbersPDFView()
        case .watermark: WatermarkPDFView()
        case .ocrText: OCRTextView()
        case .imageToPDF: ImageToPDFView()
        case .docToPDF: DocToPDFView()
        case .pdfToImage: PDFToImageView()
        case .pdfToText: PDFToTextView()
        case .signPDF: SignPDFView()
        case .cropPDF: CropPDFView()
        case .metadataEditor: MetadataEditorView()
        case .redactPDF: RedactPDFView()
        case .summarizePDF: SummarizePDFView()
        case .askPDF: AskPDFView()
        case .translatePDF: TranslatePDFView()
        case .handwriting: HandwritingView()
        case .formAutofill: FormAutofillView()
        case .emailPDF: EmailPDFView()
        case .batchProcess: BatchProcessView()
        case .comparePDF: ComparePDFView()
        case .templates: TemplatesView()
        case .qrShare: QRShareView()
        case .scanner: EmptyView()
        }
    }

    private func shouldShowTimestamp(for index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index].timestamp
        let previous = messages[index - 1].timestamp
        return current.timeIntervalSince(previous) > 300
    }

    private func deleteConversation(_ conversation: Conversation) {
        let conversationId = conversation.id
        // Cascade delete rule on Conversation.messages handles message cleanup
        modelContext.delete(conversation)
        try? modelContext.save()

        if viewModel.currentConversation?.id == conversationId {
            viewModel.currentConversation = nil
        }
    }

    // MARK: - Voice Input

    // MARK: - Slash Commands

    private func handleSlashCommand(_ cmd: SlashCommand) {
        HapticManager.medium()

        switch cmd.command {
        case "/scan":
            if let tool = coordinator.toolForId("Scanner") {
                coordinator.openTool(tool)
            }
        case "/voice":
            handleVoiceToggle()
        case "/clear":
            viewModel.currentConversation = nil
        case "/memory":
            // Post a message listing memories
            if viewModel.currentConversation == nil {
                viewModel.startNewConversation(context: modelContext)
            }
            let memories = MemoryService.shared.fetchMemories(context: modelContext)
            let content = memories.isEmpty
                ? "I don't have any memories yet. Tell me your preferences and I'll remember them!"
                : "Here's what I remember:\n\n" + memories.prefix(10).map { "• \($0.content)" }.joined(separator: "\n")
            if let conversation = viewModel.currentConversation {
                let msg = ChatMessage(content: content, role: "assistant", conversation: conversation, toolBadge: "Memory")
                modelContext.insert(msg)
                try? modelContext.save()
            }
        case "/help":
            if viewModel.currentConversation == nil {
                viewModel.startNewConversation(context: modelContext)
            }
            let helpText = """
            **Available Commands:**

            **Documents:** /scan /merge /compress /split /lock /unlock /sign /rotate /watermark /crop /pages
            **AI:** /ocr /summarize /ask /translate
            **Convert:** /convert /toimage /totext
            **Text:** /formal /casual /grammar /bullets
            **Pipelines:** /scansummary /secure
            **Utility:** /email /voice /memory /clear /help

            Or just type naturally — I'll understand!
            """
            if let conversation = viewModel.currentConversation {
                let msg = ChatMessage(content: helpText, role: "assistant", conversation: conversation, toolBadge: "Help")
                modelContext.insert(msg)
                try? modelContext.save()
            }
        case "/scansummary":
            viewModel.inputText = "scan and summarize"
            viewModel.sendMessage(context: modelContext, allMessages: allMessages)
        case "/secure":
            viewModel.inputText = "secure this pdf"
            viewModel.sendMessage(context: modelContext, allMessages: allMessages)
        case "/formal", "/casual", "/grammar", "/bullets":
            // These need a document — prompt to attach
            let toolName = cmd.label
            viewModel.inputText = toolName.lowercased()
            viewModel.sendMessage(context: modelContext, allMessages: allMessages)
        default:
            // Tool-based commands
            if let toolId = cmd.toolId {
                viewModel.startAgenticToolFlow(toolId: toolId, context: modelContext)
            } else {
                viewModel.inputText = cmd.label
                viewModel.sendMessage(context: modelContext, allMessages: allMessages)
            }
        }
    }

    private func handleVoiceToggle() {
        if speechService.isRecording {
            speechService.stopRecording()

            // Save voice note if we have a recording + transcription
            if let voiceNote = speechService.saveVoiceNote() {
                handleVoiceNote(audioURL: voiceNote.audioURL, transcription: voiceNote.transcription)
            }
        } else {
            Task {
                let authorized = await speechService.requestAuthorization()
                if authorized {
                    try? speechService.startRecording()
                }
            }
        }
    }

    private func handleVoiceNote(audioURL: URL, transcription: String) {
        guard !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Create conversation if needed
        if viewModel.currentConversation == nil {
            viewModel.startNewConversation(context: modelContext)
        }
        guard let conversation = viewModel.currentConversation else { return }

        // Import audio file
        let importService = FileImportService()
        if let imported = try? importService.importFiles(from: [audioURL], into: modelContext),
           let docFile = imported.first {
            // Store transcription as OCR cache for search
            docFile.ocrTextCache = transcription

            // Post transcription as user message
            let userMsg = ChatMessage(
                content: "🎙️ Voice note: \(transcription)",
                role: "user",
                conversation: conversation
            )
            modelContext.insert(userMsg)

            conversation.updatedAt = .now
            if conversation.title == "New Chat" {
                conversation.title = ConversationTitleGenerator.generate(from: transcription)
            }

            // Post document card with actions
            let documentId = docFile.id.uuidString
            let actions = [
                ChatAction(label: "Summary", icon: "doc.text.magnifyingglass", actionType: .executeInline, fileId: documentId, payload: "summarize"),
                ChatAction(label: "Formal", icon: "textformat", actionType: .executeInline, fileId: documentId, payload: "rewrite_formal"),
                ChatAction(label: "Bullets", icon: "list.bullet", actionType: .executeInline, fileId: documentId, payload: "bullet_points"),
                ChatAction(label: "Copy", icon: "doc.on.doc", actionType: .copyText, payload: transcription),
                ChatAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareFile, fileId: documentId),
            ]

            let duration = Int(speechService.recordingDuration)
            let cardMsg = ChatMessage(
                content: "Voice note recorded (\(duration)s). Transcription:\n\n\(transcription)",
                role: "assistant",
                conversation: conversation,
                toolBadge: "Voice Note",
                actions: actions,
                messageType: "documentCard",
                documentFileId: documentId
            )
            modelContext.insert(cardMsg)
            try? modelContext.save()
            HapticManager.success()
        }

        speechService.reset()
    }

    // MARK: - Photo Selection

    private func handlePhotoSelection(_ items: [PhotosPickerItem]) {
        guard let item = items.first else { return }
        selectedPhotos = []

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "photo_\(UUID().uuidString).jpg"
            let tempURL = tempDir.appendingPathComponent(fileName)

            do {
                try data.write(to: tempURL)
                await MainActor.run {
                    viewModel.attachFile(url: tempURL)
                }
            } catch {
                // Silently fail — user can retry
            }
        }
    }

    private func cleanupTempPhotos() {
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix("photo_") && file.pathExtension == "jpg" {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

// MARK: - Recent Files Strip

private struct RecentFilesStrip: View {
    let files: [DocumentFile]
    let onSelect: (DocumentFile) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(files) { file in
                    Button {
                        HapticManager.light()
                        onSelect(file)
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            FileTypeIcon(fileExtension: file.fileExtension, size: 14)
                            Text(file.name)
                                .font(.appMicro)
                                .foregroundStyle(Color.appText)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.appBGCard, in: Capsule())
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                    }
                    .buttonStyle(.scale)
                    .accessibilityLabel("Attach \(file.fullFileName)")
                    .accessibilityHint("Double tap to attach this file")
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
}
