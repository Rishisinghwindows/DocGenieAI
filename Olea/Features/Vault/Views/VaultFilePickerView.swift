import SwiftUI
import SwiftData

struct VaultFilePickerView: View {
    @Query(
        filter: #Predicate<DocumentFile> { $0.isInVault == false },
        sort: \DocumentFile.importedAt,
        order: .reverse
    ) private var availableFiles: [DocumentFile]

    @State private var selectedFiles: [DocumentFile] = []
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    let onAdd: ([DocumentFile]) -> Void

    private var filteredFiles: [DocumentFile] {
        if searchText.isEmpty {
            return availableFiles
        }
        let query = searchText.lowercased()
        return availableFiles.filter {
            $0.name.lowercased().contains(query) || $0.fileExtension.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availableFiles.isEmpty {
                    EmptyStateView(
                        icon: "doc",
                        title: "No Files Available",
                        message: "All your documents are already in the vault, or you haven't imported any files yet."
                    )
                } else {
                    VStack(spacing: 0) {
                        AppSearchBar(text: $searchText, placeholder: "Search files...")
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)

                        List(filteredFiles) { file in
                            Button {
                                toggleSelection(file)
                            } label: {
                                HStack(spacing: AppSpacing.md) {
                                    FileTypeIcon(fileExtension: file.fileExtension)

                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        Text(file.fullFileName)
                                            .font(.appBody)
                                            .foregroundStyle(Color.appText)
                                            .lineLimit(1)

                                        HStack(spacing: AppSpacing.sm) {
                                            if let pages = file.pageCount {
                                                Text("\(pages) pages")
                                                    .font(.appCaption)
                                                    .foregroundStyle(Color.appTextDim)
                                            }
                                            Text(file.fileSize.formattedFileSize)
                                                .font(.appCaption)
                                                .foregroundStyle(Color.appTextDim)
                                            Text(file.importedAt.relativeDisplay)
                                                .font(.appCaption)
                                                .foregroundStyle(Color.appTextDim)
                                        }
                                    }

                                    Spacer()

                                    if isSelected(file) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.appPrimary)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(Color.appTextDim)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.appBGCard)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .background(Color.appBGDark)
            .navigationTitle("Add to Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedFiles.count))") {
                        onAdd(selectedFiles)
                        dismiss()
                    }
                    .foregroundStyle(Color.appPrimary)
                    .disabled(selectedFiles.isEmpty)
                }
            }
        }
    }

    private func isSelected(_ file: DocumentFile) -> Bool {
        selectedFiles.contains { $0.id == file.id }
    }

    private func toggleSelection(_ file: DocumentFile) {
        if let index = selectedFiles.firstIndex(where: { $0.id == file.id }) {
            selectedFiles.remove(at: index)
        } else {
            selectedFiles.append(file)
        }
        HapticManager.selection()
    }
}
