import SwiftUI
import SwiftData

struct MoveToFolderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DocumentFolder.createdAt, order: .reverse) private var folders: [DocumentFolder]

    let file: DocumentFile

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBGDark.ignoresSafeArea()

                if folders.isEmpty {
                    EmptyStateView(
                        icon: "folder.badge.plus",
                        title: "No Folders",
                        message: "Create folders from the Files tab to organize your documents."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.sm) {
                            // Remove from folder option
                            if file.folderID != nil {
                                AppCard {
                                    HStack(spacing: AppSpacing.md) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.appBody)
                                            .foregroundStyle(Color.appTextMuted)
                                            .frame(width: 24)

                                        Text("Remove from Folder")
                                            .font(.appBody)
                                            .foregroundStyle(Color.appText)

                                        Spacer()
                                    }
                                    .padding(AppSpacing.md)
                                    .contentShape(Rectangle())
                                }
                                .onTapGesture {
                                    file.folderID = nil
                                    try? modelContext.save()
                                    HapticManager.success()
                                    dismiss()
                                }
                            }

                            ForEach(folders) { folder in
                                let isCurrentFolder = file.folderID == folder.id

                                AppCard {
                                    HStack(spacing: AppSpacing.md) {
                                        Circle()
                                            .fill(folder.color)
                                            .frame(width: 12, height: 12)

                                        Image(systemName: folder.iconName)
                                            .font(.appBody)
                                            .foregroundStyle(folder.color)
                                            .frame(width: 24)

                                        Text(folder.name)
                                            .font(.appBody)
                                            .foregroundStyle(Color.appText)
                                            .lineLimit(1)

                                        Spacer()

                                        if isCurrentFolder {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.appSuccess)
                                        }
                                    }
                                    .padding(AppSpacing.md)
                                    .contentShape(Rectangle())
                                }
                                .onTapGesture {
                                    guard !isCurrentFolder else { return }
                                    file.folderID = folder.id
                                    try? modelContext.save()
                                    HapticManager.success()
                                    dismiss()
                                }
                                .staggeredAppear(index: folders.firstIndex(of: folder) ?? 0)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }
}
