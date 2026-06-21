import SwiftUI
import SwiftData

struct ExpiryDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DocumentFile.expiryDate) private var allFiles: [DocumentFile]

    @State private var fileToEdit: DocumentFile?

    private var filesWithExpiry: [DocumentFile] {
        allFiles.filter { $0.expiryDate != nil }
    }

    private var expiredFiles: [DocumentFile] {
        filesWithExpiry.filter { $0.isExpired }
    }

    private var expiringSoonFiles: [DocumentFile] {
        filesWithExpiry.filter { $0.isExpiringSoon }
    }

    private var upcomingFiles: [DocumentFile] {
        filesWithExpiry.filter { !$0.isExpired && !$0.isExpiringSoon }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filesWithExpiry.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "No Expiry Dates",
                        message: "Set expiry dates on your documents to track renewals and deadlines."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            if !expiredFiles.isEmpty {
                                expirySection(title: "Expired", files: expiredFiles, color: .appDanger)
                            }
                            if !expiringSoonFiles.isEmpty {
                                expirySection(title: "Expiring Soon", files: expiringSoonFiles, color: .appWarning)
                            }
                            if !upcomingFiles.isEmpty {
                                expirySection(title: "Upcoming", files: upcomingFiles, color: .appTextMuted)
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }
            }
            .background(Color.appBGDark)
            .navigationTitle("Expiry Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
            }
            .sheet(item: $fileToEdit) { file in
                SetExpirySheet(file: file)
            }
        }
    }

    @ViewBuilder
    private func expirySection(title: String, files: [DocumentFile], color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.appH3)
                .foregroundStyle(color)
                .padding(.leading, AppSpacing.xs)

            VStack(spacing: AppSpacing.sm) {
                ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                    Button {
                        HapticManager.selection()
                        fileToEdit = file
                    } label: {
                        expiryRow(file: file, color: color)
                    }
                    .buttonStyle(.plain)
                    .staggeredAppear(index: index)
                }
            }
        }
    }

    private func expiryRow(file: DocumentFile, color: Color) -> some View {
        HStack(spacing: AppSpacing.md) {
            FileTypeIcon(fileExtension: file.fileExtension)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(file.fullFileName)
                    .font(.appBody)
                    .foregroundStyle(Color.appText)
                    .lineLimit(1)

                if let note = file.expiryNote, !note.isEmpty {
                    Text(note)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextDim)
                        .lineLimit(1)
                }

                if let expiryDate = file.expiryDate {
                    Text(expiryDate, style: .date)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextDim)
                }
            }

            Spacer()

            daysBadge(for: file, color: color)
        }
        .padding(AppSpacing.md)
        .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func daysBadge(for file: DocumentFile, color: Color) -> some View {
        if let days = file.daysUntilExpiry {
            let text: String = {
                if days < 0 {
                    return "\(abs(days))d ago"
                } else if days == 0 {
                    return "Today"
                } else {
                    return "\(days)d left"
                }
            }()

            Text(text)
                .font(.appMicro)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(color, in: Capsule())
        }
    }
}
