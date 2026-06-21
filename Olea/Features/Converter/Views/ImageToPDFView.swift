import SwiftUI
import SwiftData

struct ImageToPDFView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DocumentFile.importedAt, order: .reverse) private var allFiles: [DocumentFile]
    @State private var viewModel = ConverterViewModel()
    @State private var selectedFiles: [DocumentFile] = []
    @State private var showPicker = false
    @State private var outputName = ""

    private var imageFiles: [DocumentFile] {
        allFiles.filter { ["jpg", "jpeg", "png", "heic", "bmp", "gif", "tiff", "webp"].contains($0.fileExtension.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Images") {
                    Button { showPicker = true } label: {
                        Label(
                            selectedFiles.isEmpty ? "Choose images" : "\(selectedFiles.count) images selected",
                            systemImage: "photo.on.rectangle"
                        ).font(.appBody)
                    }

                    ForEach(selectedFiles) { file in
                        HStack {
                            FileTypeIcon(fileExtension: file.fileExtension)
                            Text(file.fullFileName).font(.appBody).lineLimit(1)
                        }
                    }
                }

                Section("Output Name") {
                    TextField("Combined images", text: $outputName)
                        .font(.appBody).autocorrectionDisabled()
                }

                if viewModel.didComplete, let name = viewModel.resultFileName {
                    Section {
                        VStack(spacing: AppSpacing.sm) {
                            AnimatedCheckmark()
                            Text("Saved as \(name)")
                                .font(.appBody)
                                .foregroundStyle(Color.appSuccess)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.appSuccess.opacity(0.05))
                    }
                }
            }
            .navigationTitle("Image to PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isProcessing { ProgressView() }
                    else if viewModel.didComplete { Button("Done") { dismiss() } }
                    else {
                        Button("Convert") { convert() }
                            .disabled(selectedFiles.isEmpty || outputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                ImageFilePickerSheet(files: imageFiles, selectedFiles: $selectedFiles)
            }
            .alert("Error", isPresented: $viewModel.showError) { Button("OK") {} } message: {
                Text(viewModel.errorMessage ?? "An error occurred.")
            }
            .confettiOnComplete(viewModel.didComplete)
        }
    }

    private func convert() {
        let urls = selectedFiles.compactMap { $0.fileURL }
        guard !urls.isEmpty else { return }
        viewModel.imagesToPDF(urls: urls, outputName: outputName, context: modelContext)
    }
}

private struct ImageFilePickerSheet: View {
    let files: [DocumentFile]
    @Binding var selectedFiles: [DocumentFile]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if files.isEmpty {
                    EmptyStateView(icon: "photo", title: "No Images", message: "Import image files first.", buttonTitle: "Import Files", action: { dismiss() })
                } else {
                    List(files) { file in
                        Button {
                            if let idx = selectedFiles.firstIndex(where: { $0.id == file.id }) {
                                selectedFiles.remove(at: idx)
                            } else {
                                selectedFiles.append(file)
                            }
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                FileTypeIcon(fileExtension: file.fileExtension)
                                Text(file.fullFileName).font(.appBody).foregroundStyle(Color.appText).lineLimit(1)
                                Spacer()
                                if selectedFiles.contains(where: { $0.id == file.id }) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.appPrimary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { selectedFiles = []; dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(selectedFiles.isEmpty) }
            }
        }
    }
}
