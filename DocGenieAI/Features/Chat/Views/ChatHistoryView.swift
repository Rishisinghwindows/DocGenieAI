import SwiftUI

struct ChatHistoryView: View {
    let conversations: [Conversation]
    let onSelect: (Conversation) -> Void
    let onDelete: (Conversation) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var pinnedConversations: [Conversation] {
        conversations.filter { $0.isPinned }
    }

    private var unpinnedConversations: [Conversation] {
        conversations.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "No Conversations",
                        message: "Start a new chat to see your history here.",
                        buttonTitle: "Start a Chat",
                        action: { dismiss() }
                    )
                } else {
                    List {
                        if !pinnedConversations.isEmpty {
                            Section {
                                ForEach(Array(pinnedConversations.enumerated()), id: \.element.id) { index, conversation in
                                    conversationRow(conversation, index: index)
                                }
                            } header: {
                                Label("Pinned", systemImage: "pin.fill")
                                    .font(.appMicro)
                                    .foregroundStyle(Color.appPrimary)
                                    .textCase(nil)
                            }
                        }

                        Section {
                            ForEach(Array(unpinnedConversations.enumerated()), id: \.element.id) { index, conversation in
                                conversationRow(conversation, index: index)
                            }
                        } header: {
                            if !pinnedConversations.isEmpty {
                                Text("Recent")
                                    .font(.appMicro)
                                    .foregroundStyle(Color.appTextDim)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.appBGDark)
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func conversationRow(_ conversation: Conversation, index: Int) -> some View {
        Button {
            HapticManager.selection()
            onSelect(conversation)
        } label: {
            HStack {
                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appPrimary)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(conversation.title)
                        .font(.appBody)
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)

                    if let lastMessage = conversation.messages?.sorted(by: { $0.timestamp < $1.timestamp }).last {
                        Text(lastMessage.content)
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextMuted)
                            .lineLimit(1)
                    }

                    HStack(spacing: AppSpacing.xs) {
                        Text(conversation.updatedAt.relativeDisplay)
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextDim)

                        if let count = conversation.messages?.count, count > 0 {
                            Text("·")
                                .foregroundStyle(Color.appTextDim)
                            Text("\(count) messages")
                                .font(.appMicro)
                                .foregroundStyle(Color.appTextDim)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextDim)
            }
            .padding(AppSpacing.md)
            .glassCard(cornerRadius: AppCornerRadius.md)
        }
        .buttonStyle(.scale)
        .staggeredAppear(index: index)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: AppSpacing.xs, leading: AppSpacing.md, bottom: AppSpacing.xs, trailing: AppSpacing.md))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                HapticManager.medium()
                onDelete(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                HapticManager.light()
                conversation.isPinned.toggle()
                try? modelContext.save()
            } label: {
                Label(conversation.isPinned ? "Unpin" : "Pin",
                      systemImage: conversation.isPinned ? "pin.slash" : "pin")
            }
            .tint(Color.appPrimary)
        }
        .contextMenu {
            Button {
                conversation.isPinned.toggle()
                try? modelContext.save()
            } label: {
                Label(conversation.isPinned ? "Unpin" : "Pin",
                      systemImage: conversation.isPinned ? "pin.slash" : "pin")
            }
            Button {
                if let msgs = conversation.messages {
                    if let url = ChatExportService.shared.exportConversation(conversation, messages: msgs) {
                        ShareService.shared.share(fileURL: url)
                    }
                }
            } label: {
                Label("Export PDF", systemImage: "arrow.down.doc")
            }
            Button(role: .destructive) {
                onDelete(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
