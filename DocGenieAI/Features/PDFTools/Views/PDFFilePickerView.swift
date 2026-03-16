import SwiftUI
import SwiftData

struct PDFFilePickerView: View {
    @Query(
        filter: #Predicate<DocumentFile> { $0.fileExtension == "pdf" },
        sort: \DocumentFile.importedAt,
        order: .reverse
    ) private var pdfFiles: [DocumentFile]

    let title: String
    let allowsMultiple: Bool
    @Binding var selectedFiles: [DocumentFile]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if pdfFiles.isEmpty {
                    EmptyStateView(
                        icon: "doc.richtext",
                        title: "No PDFs",
                        message: "Import PDF files first from the Files tab.",
                        buttonTitle: "Import Files",
                        action: { dismiss() }
                    )
                } else {
                    List(pdfFiles) { file in
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
                                    }
                                }

                                Spacer()

                                if isSelected(file) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.appPrimary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedFiles = []
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(selectedFiles.isEmpty)
                }
            }
        }
    }

    private func isSelected(_ file: DocumentFile) -> Bool {
        selectedFiles.contains { $0.id == file.id }
    }

    private func toggleSelection(_ file: DocumentFile) {
        if allowsMultiple {
            if let index = selectedFiles.firstIndex(where: { $0.id == file.id }) {
                selectedFiles.remove(at: index)
            } else {
                selectedFiles.append(file)
            }
        } else {
            selectedFiles = [file]
            dismiss()
        }
    }
}
