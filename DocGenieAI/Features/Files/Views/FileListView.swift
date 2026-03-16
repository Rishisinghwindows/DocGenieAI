import SwiftUI

struct FileListView: View {
    let files: [DocumentFile]
    let onSelect: (DocumentFile) -> Void
    let onAction: (DocumentFile, FileRowAction) -> Void
    var isSelecting: Bool = false
    @Binding var selectedFiles: Set<UUID>

    init(files: [DocumentFile],
         onSelect: @escaping (DocumentFile) -> Void,
         onAction: @escaping (DocumentFile, FileRowAction) -> Void,
         isSelecting: Bool = false,
         selectedFiles: Binding<Set<UUID>> = .constant([])) {
        self.files = files
        self.onSelect = onSelect
        self.onAction = onAction
        self.isSelecting = isSelecting
        self._selectedFiles = selectedFiles
    }

    var body: some View {
        if files.isEmpty {
            EmptyStateView(
                icon: "doc.on.doc",
                title: "No Files Yet",
                message: "Import documents to get started. Tap the + button to browse your files."
            )
            .frame(maxHeight: .infinity)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                    Button {
                        if isSelecting {
                            HapticManager.light()
                            if selectedFiles.contains(file.id) {
                                selectedFiles.remove(file.id)
                            } else {
                                selectedFiles.insert(file.id)
                            }
                        } else {
                            onSelect(file)
                        }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            if isSelecting {
                                Image(systemName: selectedFiles.contains(file.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedFiles.contains(file.id) ? Color.appPrimary : Color.appTextDim)
                                    .font(.system(size: 22))
                                    .animation(.easeInOut(duration: 0.2), value: selectedFiles.contains(file.id))
                            }

                            FileRowView(file: file) { action in
                                onAction(file, action)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !isSelecting {
                            Button(role: .destructive) {
                                HapticManager.medium()
                                onAction(file, .delete)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                HapticManager.light()
                                onAction(file, .share)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if !isSelecting {
                            Button {
                                HapticManager.light()
                                onAction(file, .toggleFavorite)
                            } label: {
                                Label(
                                    file.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: file.isFavorite ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))

                    Divider()
                        .background(Color.appBorder)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: files.map(\.id))
        }
    }
}
