import SwiftUI
import SwiftData

// MARK: - Batch Operation

enum BatchOperation: String, CaseIterable, Identifiable {
    case compress = "Compress"
    case rotate = "Rotate 90\u{00B0}"
    case pageNumbers = "Add Page Numbers"
    case watermark = "Add Watermark"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .compress: return "arrow.down.doc"
        case .rotate: return "rotate.right"
        case .pageNumbers: return "number.square"
        case .watermark: return "drop.triangle"
        }
    }

    var description: String {
        switch self {
        case .compress: return "Reduce file size for all selected PDFs"
        case .rotate: return "Rotate all pages 90\u{00B0} clockwise"
        case .pageNumbers: return "Add page numbers to every PDF"
        case .watermark: return "Apply a text watermark to all PDFs"
        }
    }
}

// MARK: - Batch File Result

struct BatchFileResult: Identifiable {
    let id = UUID()
    let fileName: String
    let succeeded: Bool
    let error: String?
}

// MARK: - View

struct BatchProcessView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // File selection
    @State private var selectedFiles: [DocumentFile] = []
    @State private var showPicker = false

    // Operation config
    @State private var selectedOperation: BatchOperation = .compress
    @State private var compressionLevel: PDFToolsService.CompressionLevel = .medium
    @State private var watermarkText = ""

    // Processing state
    @State private var isProcessing = false
    @State private var currentFileIndex = 0
    @State private var results: [BatchFileResult] = []
    @State private var didComplete = false

    // Errors
    @State private var showError = false
    @State private var errorMessage: String?

    private let service = PDFToolsService.shared

    private var successCount: Int { results.filter(\.succeeded).count }
    private var failCount: Int { results.filter { !$0.succeeded }.count }

    private var canProcess: Bool {
        guard !selectedFiles.isEmpty else { return false }
        if selectedOperation == .watermark {
            return !watermarkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                fileSelectionSection
                operationSection
                operationOptionsSection
                if isProcessing { progressSection }
                if didComplete { resultsSection }
            }
            .navigationTitle("Batch Process")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isProcessing {
                        ProgressView()
                    } else if didComplete {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Process") { startBatch() }
                            .disabled(!canProcess)
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                PDFFilePickerView(
                    title: "Select PDFs",
                    allowsMultiple: true,
                    selectedFiles: $selectedFiles
                )
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
            .confettiOnComplete(didComplete)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var fileSelectionSection: some View {
        Section {
            Button { showPicker = true } label: {
                if selectedFiles.isEmpty {
                    Label("Choose PDFs", systemImage: "doc.richtext")
                        .font(.appBody)
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Label("\(selectedFiles.count) PDF\(selectedFiles.count == 1 ? "" : "s") selected",
                              systemImage: "doc.on.doc.fill")
                            .font(.appBody)
                            .foregroundStyle(Color.appPrimary)
                    }
                }
            }
            .disabled(isProcessing || didComplete)

            if !selectedFiles.isEmpty {
                ForEach(selectedFiles) { file in
                    HStack(spacing: AppSpacing.sm) {
                        FileTypeIcon(fileExtension: "pdf")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.fullFileName)
                                .font(.appBody)
                                .lineLimit(1)
                            Text(file.fileSize.formattedFileSize)
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextDim)
                        }
                    }
                }
            }
        } header: {
            Text("Select PDFs")
        } footer: {
            if !selectedFiles.isEmpty {
                Text("Tap \"Choose PDFs\" to change your selection.")
                    .font(.appCaption)
            }
        }
    }

    @ViewBuilder
    private var operationSection: some View {
        Section("Operation") {
            ForEach(BatchOperation.allCases) { operation in
                Button {
                    selectedOperation = operation
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: operation.icon)
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(operation.rawValue)
                                .font(.appBody)
                                .foregroundStyle(Color.appText)
                            Text(operation.description)
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextMuted)
                        }
                        Spacer()
                        if selectedOperation == operation {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.appPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || didComplete)
            }
        }
    }

    @ViewBuilder
    private var operationOptionsSection: some View {
        switch selectedOperation {
        case .compress:
            Section("Compression Level") {
                ForEach(PDFToolsService.CompressionLevel.allCases) { level in
                    Button {
                        compressionLevel = level
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(level.rawValue)
                                    .font(.appBody)
                                    .foregroundStyle(Color.appText)
                                Text(level.description)
                                    .font(.appCaption)
                                    .foregroundStyle(Color.appTextMuted)
                            }
                            Spacer()
                            if compressionLevel == level {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.appPrimary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing || didComplete)
                }
            }

        case .watermark:
            Section("Watermark Text") {
                TextField("e.g. CONFIDENTIAL", text: $watermarkText)
                    .font(.appBody)
                    .disabled(isProcessing || didComplete)
                Text("Text will appear diagonally across each page with transparency.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
            }

        case .rotate, .pageNumbers:
            EmptyView()
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        Section("Progress") {
            VStack(spacing: AppSpacing.sm) {
                ProgressView(value: Double(currentFileIndex), total: Double(selectedFiles.count))
                    .tint(Color.appPrimary)

                HStack {
                    Text("Processing \(currentFileIndex + 1) of \(selectedFiles.count)")
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextMuted)
                    Spacer()
                    Text("\(Int((Double(currentFileIndex) / Double(selectedFiles.count)) * 100))%")
                        .font(.appCaption)
                        .foregroundStyle(Color.appPrimary)
                }

                if currentFileIndex < selectedFiles.count {
                    Text(selectedFiles[currentFileIndex].fullFileName)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextDim)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, AppSpacing.xs)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        Section {
            VStack(spacing: AppSpacing.sm) {
                AnimatedCheckmark()

                Text("Batch Complete")
                    .font(.appH3)
                    .foregroundStyle(Color.appText)

                HStack(spacing: AppSpacing.lg) {
                    VStack(spacing: AppSpacing.xs) {
                        Text("\(successCount)")
                            .font(.appH2)
                            .foregroundStyle(Color.appSuccess)
                        Text("Succeeded")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextMuted)
                    }

                    if failCount > 0 {
                        VStack(spacing: AppSpacing.xs) {
                            Text("\(failCount)")
                                .font(.appH2)
                                .foregroundStyle(Color.appDanger)
                            Text("Failed")
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextMuted)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .listRowBackground(Color.appSuccess.opacity(0.05))
        }

        if !results.isEmpty {
            Section("Details") {
                ForEach(results) { result in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.succeeded ? Color.appSuccess : Color.appDanger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.fileName)
                                .font(.appBody)
                                .lineLimit(1)
                            if let error = result.error {
                                Text(error)
                                    .font(.appCaption)
                                    .foregroundStyle(Color.appDanger)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Processing

    private func startBatch() {
        guard canProcess else { return }
        isProcessing = true
        currentFileIndex = 0
        results = []
        HapticManager.medium()

        Task { @MainActor in
            for (index, file) in selectedFiles.enumerated() {
                currentFileIndex = index
                guard let url = file.fileURL else {
                    results.append(BatchFileResult(fileName: file.fullFileName, succeeded: false, error: "File not accessible"))
                    continue
                }

                let outputName = outputNameForFile(file)

                do {
                    let result = try await performOperation(on: url, outputName: outputName)
                    try saveResult(url: result.url, relativePath: result.relativePath)
                    results.append(BatchFileResult(fileName: file.fullFileName, succeeded: true, error: nil))
                } catch {
                    results.append(BatchFileResult(fileName: file.fullFileName, succeeded: false, error: error.localizedDescription))
                }
            }

            isProcessing = false
            didComplete = true

            if failCount == 0 {
                HapticManager.success()
            } else {
                HapticManager.error()
            }
        }
    }

    private func performOperation(on url: URL, outputName: String) async throws -> (url: URL, relativePath: String) {
        switch selectedOperation {
        case .compress:
            return try await service.compressPDF(from: url, level: compressionLevel, outputName: outputName)
        case .rotate:
            return try await service.rotatePDF(from: url, degrees: 90, outputName: outputName)
        case .pageNumbers:
            return try await service.addPageNumbers(from: url, outputName: outputName)
        case .watermark:
            return try await service.addWatermark(from: url, text: watermarkText, outputName: outputName)
        }
    }

    private func outputNameForFile(_ file: DocumentFile) -> String {
        let baseName = file.name
        switch selectedOperation {
        case .compress: return "\(baseName) (compressed)"
        case .rotate: return "\(baseName) (rotated)"
        case .pageNumbers: return "\(baseName) (numbered)"
        case .watermark: return "\(baseName) (watermarked)"
        }
    }

    private func saveResult(url: URL, relativePath: String) throws {
        let metadata = FileMetadataService.shared.extractMetadata(from: url)
        let docFile = DocumentFile(
            name: (url.lastPathComponent as NSString).deletingPathExtension,
            fileExtension: "pdf",
            relativeFilePath: relativePath,
            fileSize: metadata.fileSize,
            pageCount: metadata.pageCount
        )
        modelContext.insert(docFile)
        try modelContext.save()

        NotificationCenter.default.post(
            name: .toolDidProduceDocument,
            object: nil,
            userInfo: ["documentId": docFile.id.uuidString, "toolName": "Batch Process"]
        )
    }
}
