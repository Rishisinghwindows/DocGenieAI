import SwiftUI
import SwiftData

struct DocumentCardBubbleView: View {
    let message: ChatMessage
    var onAction: ((ChatAction) -> Void)?
    @Query private var documents: [DocumentFile]

    init(message: ChatMessage, onAction: ((ChatAction) -> Void)? = nil) {
        self.message = message
        self.onAction = onAction
        _documents = Query(sort: \DocumentFile.importedAt)
    }

    private var document: DocumentFile? {
        documents.first { $0.id.uuidString == message.documentFileId }
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // AI avatar
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.appCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.appPrimary)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Badge
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 10))
                    Text(badgeLabel)
                        .font(.appMicro)
                }
                .foregroundStyle(Color.appPrimary)

                // Document Card — compact
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        // Thumbnail — compact
                        if let pageCount = document?.pageCount, pageCount > 1 {
                            ScanPageThumbnailStrip(
                                documentFileId: message.documentFileId,
                                pageCount: pageCount
                            )
                            .frame(width: 48, height: 56)
                        } else {
                            PDFThumbnailView(documentFileId: message.documentFileId)
                                .frame(width: 48, height: 56)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.content)
                                .font(.appCaption)
                                .foregroundStyle(Color.appText)
                                .lineLimit(2)

                            if !message.documentFileId.isEmpty {
                                DocumentMetadataRow(documentFileId: message.documentFileId)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Action chips — compact horizontal scroll
                    let actions = message.actions
                    if !actions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.xs) {
                                ForEach(actions) { action in
                                    Button {
                                        HapticManager.light()
                                        onAction?(action)
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: action.icon)
                                                .font(.system(size: 10))
                                            Text(action.label)
                                                .font(.appMicro)
                                        }
                                        .foregroundStyle(Color.appPrimary)
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, 5)
                                        .background(Color.appPrimary.opacity(0.1), in: Capsule())
                                    }
                                    .buttonStyle(.scale)
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: AppCornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                        .stroke(
                            LinearGradient(
                                colors: [Color.appPrimary.opacity(0.6), Color.appAccent.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .glow(color: .appPrimary, radius: 6)
            }
        }
    }

    private var badgeIcon: String {
        message.toolBadge == "Scanner" ? "doc.viewfinder" : "doc.badge.arrow.up"
    }

    private var badgeLabel: String {
        message.toolBadge ?? "Document"
    }
}
