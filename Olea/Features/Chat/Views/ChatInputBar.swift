import SwiftUI

// MARK: - Slash Commands

struct SlashCommand: Identifiable {
    let id = UUID()
    let command: String
    let label: String
    let icon: String
    let description: String
    let toolId: String?

    static let all: [SlashCommand] = [
        // Document tools
        SlashCommand(command: "/scan", label: "Scan", icon: "doc.viewfinder", description: "Scan a document with camera", toolId: "Scanner"),
        SlashCommand(command: "/merge", label: "Merge", icon: "doc.on.doc.fill", description: "Combine multiple PDFs", toolId: "Merge PDF"),
        SlashCommand(command: "/compress", label: "Compress", icon: "arrow.down.doc", description: "Reduce PDF file size", toolId: "Compress"),
        SlashCommand(command: "/split", label: "Split", icon: "scissors", description: "Split PDF by pages", toolId: "Split PDF"),
        SlashCommand(command: "/lock", label: "Lock", icon: "lock.doc", description: "Password-protect a PDF", toolId: "Lock PDF"),
        SlashCommand(command: "/unlock", label: "Unlock", icon: "lock.open", description: "Remove PDF password", toolId: "Unlock PDF"),
        SlashCommand(command: "/sign", label: "Sign", icon: "signature", description: "Add signature to PDF", toolId: "Sign PDF"),
        SlashCommand(command: "/rotate", label: "Rotate", icon: "rotate.right", description: "Rotate PDF pages", toolId: "Rotate PDF"),
        SlashCommand(command: "/watermark", label: "Watermark", icon: "drop.triangle", description: "Add text watermark", toolId: "Watermark"),
        SlashCommand(command: "/crop", label: "Crop", icon: "crop", description: "Crop PDF margins", toolId: "Crop PDF"),
        SlashCommand(command: "/pages", label: "Page Numbers", icon: "number.square", description: "Add page numbers", toolId: "Page Numbers"),

        // OCR & AI
        SlashCommand(command: "/ocr", label: "OCR", icon: "text.viewfinder", description: "Extract text from document", toolId: "OCR Text"),
        SlashCommand(command: "/summarize", label: "Summarize", icon: "doc.text.magnifyingglass", description: "AI summary of document", toolId: "Summarize PDF"),
        SlashCommand(command: "/ask", label: "Ask", icon: "questionmark.bubble", description: "Ask questions about a document", toolId: "Ask PDF"),
        SlashCommand(command: "/translate", label: "Translate", icon: "textformat.abc", description: "Translate document text", toolId: "Translate PDF"),

        // Converters
        SlashCommand(command: "/convert", label: "Convert", icon: "arrow.triangle.2.circlepath", description: "Convert file to PDF", toolId: "Doc to PDF"),
        SlashCommand(command: "/toimage", label: "PDF to Image", icon: "photo", description: "Export PDF as images", toolId: "PDF to Image"),
        SlashCommand(command: "/totext", label: "PDF to Text", icon: "doc.plaintext", description: "Extract all text from PDF", toolId: "PDF to Text"),

        // Text actions
        SlashCommand(command: "/formal", label: "Formal", icon: "textformat", description: "Rewrite in formal tone", toolId: nil),
        SlashCommand(command: "/casual", label: "Casual", icon: "text.bubble", description: "Rewrite in casual tone", toolId: nil),
        SlashCommand(command: "/grammar", label: "Fix Grammar", icon: "checkmark.circle", description: "Fix spelling & grammar", toolId: nil),
        SlashCommand(command: "/bullets", label: "Bullets", icon: "list.bullet", description: "Convert to bullet points", toolId: nil),

        // Pipelines
        SlashCommand(command: "/scansummary", label: "Scan & Summarize", icon: "sparkles", description: "OCR then summarize", toolId: nil),
        SlashCommand(command: "/secure", label: "Secure PDF", icon: "lock.shield", description: "Compress + watermark", toolId: nil),

        // Utility
        SlashCommand(command: "/email", label: "Email", icon: "envelope", description: "Email a PDF", toolId: "Email PDF"),
        SlashCommand(command: "/voice", label: "Voice Note", icon: "mic.fill", description: "Record a voice note", toolId: nil),
        SlashCommand(command: "/memory", label: "Memory", icon: "brain", description: "View what I remember about you", toolId: nil),
        SlashCommand(command: "/clear", label: "New Chat", icon: "plus.bubble", description: "Start a fresh conversation", toolId: nil),
        SlashCommand(command: "/help", label: "Help", icon: "questionmark.circle", description: "Show all commands", toolId: nil),
    ]
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    let isTyping: Bool
    let pendingAttachment: PendingAttachment?
    let isRecording: Bool
    let audioLevel: Float
    let onSend: () -> Void
    let onAttachTapped: () -> Void
    let onVoiceToggle: () -> Void
    let onRemoveAttachment: () -> Void
    var onSlashCommand: ((SlashCommand) -> Void)?

    @State private var showSlashMenu = false

    private var filteredCommands: [SlashCommand] {
        let query = text.lowercased()
        if query == "/" { return SlashCommand.all }
        guard query.hasPrefix("/") else { return [] }
        let search = String(query.dropFirst())
        return SlashCommand.all.filter {
            $0.command.contains(query) || $0.label.lowercased().contains(search) || $0.description.lowercased().contains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Slash command popup
            if showSlashMenu && !filteredCommands.isEmpty {
                slashCommandMenu
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Attachment preview
            if let attachment = pendingAttachment {
                AttachmentPreviewStrip(
                    attachment: attachment,
                    onRemove: onRemoveAttachment
                )
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xs)
            }

            // Floating pill input
            HStack(spacing: AppSpacing.sm) {
                Button {
                    HapticManager.light()
                    onAttachTapped()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.appTextMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Attach file")

                // Slash hint
                Button {
                    text = "/"
                    showSlashMenu = true
                } label: {
                    Text("/")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.appTextDim)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Slash commands")
                .accessibilityHint("Double tap to show available commands")

                TextField("Message", text: $text, axis: .vertical)
                    .font(.appBody)
                    .lineLimit(1...5)
                    .foregroundStyle(Color.appText)
                    .appWritingTools()
                    .onChange(of: text) { _, newValue in
                        withAnimation(.easeOut(duration: 0.15)) {
                            showSlashMenu = newValue.hasPrefix("/")
                        }
                    }

                if canSend || isTyping {
                    Button {
                        HapticManager.medium()
                        // Check if it's a slash command
                        if text.hasPrefix("/"), let cmd = matchExactCommand() {
                            onSlashCommand?(cmd)
                            text = ""
                            showSlashMenu = false
                        } else {
                            onSend()
                        }
                    } label: {
                        Image(systemName: isTyping ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(canSend ? Color.appPrimary : Color.appTextDim)
                    }
                    .disabled(!canSend || isTyping)
                    .accessibilityLabel("Send message")
                    .transition(.scale.combined(with: .opacity))
                } else {
                    if isRecording {
                        VoicePulseView(audioLevel: audioLevel)
                            .onTapGesture {
                                HapticManager.medium()
                                onVoiceToggle()
                            }
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Button {
                            HapticManager.light()
                            onVoiceToggle()
                        } label: {
                            Image(systemName: "mic")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.appTextMuted)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Voice input")
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.appBGCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
            )
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xs)
        }
        .animation(AppAnimations.springQuick, value: canSend)
        .animation(AppAnimations.springQuick, value: isRecording)
        .animation(AppAnimations.springSmooth, value: pendingAttachment != nil)
    }

    // MARK: - Slash Command Menu

    private var slashCommandMenu: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredCommands) { cmd in
                    Button {
                        HapticManager.light()
                        onSlashCommand?(cmd)
                        text = ""
                        withAnimation { showSlashMenu = false }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: cmd.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.appPrimary)
                                .frame(width: 28, height: 28)
                                .background(Color.appPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(cmd.command)
                                        .font(.appMono)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.appPrimary)
                                    Text(LocalizedStringKey(cmd.label))
                                        .font(.appCaption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.appText)
                                }
                                Text(cmd.description)
                                    .font(.appMicro)
                                    .foregroundStyle(Color.appTextDim)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 8)
                    }

                    if cmd.id != filteredCommands.last?.id {
                        Divider().background(Color.appBorder).padding(.leading, 54)
                    }
                }
            }
        }
        .frame(maxHeight: 250)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appBGCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
        )
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingAttachment != nil
    }

    private func matchExactCommand() -> SlashCommand? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return SlashCommand.all.first { $0.command == trimmed }
    }
}
