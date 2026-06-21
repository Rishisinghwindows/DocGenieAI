import SwiftUI
import SwiftData
import PDFKit

struct RedactPDFView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedFiles: [DocumentFile] = []
    @State private var showPicker = false
    @State private var isAnalyzing = false
    @State private var isRedacting = false
    @State private var didComplete = false
    @State private var resultFileName: String?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var outputName = ""

    // PII detection state
    @State private var detectedItems: [PIIItem] = []
    @State private var extractedText = ""

    private let piiService = PIIDetectionService.shared

    private var selectedFile: DocumentFile? { selectedFiles.first }

    private var selectedCount: Int {
        detectedItems.filter(\.isSelected).count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Select PDF") {
                    Button {
                        showPicker = true
                    } label: {
                        if let file = selectedFile {
                            HStack {
                                FileTypeIcon(fileExtension: "pdf")
                                VStack(alignment: .leading) {
                                    Text(file.fullFileName)
                                        .font(.appBody)
                                        .lineLimit(1)
                                    Text(file.fileSize.formattedFileSize)
                                        .font(.appCaption)
                                        .foregroundStyle(Color.appTextDim)
                                }
                            }
                        } else {
                            Label("Choose a PDF", systemImage: "doc.richtext")
                                .font(.appBody)
                        }
                    }
                }

                if isAnalyzing {
                    Section {
                        HStack(spacing: AppSpacing.md) {
                            ProgressView()
                            Text("Scanning for sensitive data...")
                                .font(.appBody)
                                .foregroundStyle(Color.appTextMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                if !detectedItems.isEmpty {
                    Section {
                        HStack {
                            Text("Detected Items")
                                .font(.appH3)
                            Spacer()
                            Text("\(selectedCount) of \(detectedItems.count) selected")
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextMuted)
                        }

                        Button {
                            let allSelected = detectedItems.allSatisfy(\.isSelected)
                            for i in detectedItems.indices {
                                detectedItems[i].isSelected = !allSelected
                            }
                        } label: {
                            Text(detectedItems.allSatisfy(\.isSelected) ? "Deselect All" : "Select All")
                                .font(.appCaption)
                                .foregroundStyle(Color.appPrimary)
                        }
                    }

                    Section {
                        ForEach($detectedItems) { $item in
                            PIIItemRow(item: $item)
                        }
                    }

                    Section("Output Name") {
                        TextField("Redacted document", text: $outputName)
                            .font(.appBody)
                            .autocorrectionDisabled()
                    }
                }

                if detectedItems.isEmpty && !isAnalyzing && selectedFile != nil && !extractedText.isEmpty {
                    Section {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.appSuccess)
                            Text("No sensitive data detected")
                                .font(.appBody)
                                .foregroundStyle(Color.appSuccess)
                            Text("This document appears clean of PII.")
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.appSuccess.opacity(0.05))
                    }
                }

                if didComplete, let name = resultFileName {
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
            .navigationTitle("Redact PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAnalyzing || isRedacting {
                        ProgressView()
                    } else if didComplete {
                        Button("Done") { dismiss() }
                    } else if !detectedItems.isEmpty {
                        Button("Redact") { redactDocument() }
                            .disabled(selectedCount == 0 || outputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button("Analyze") { analyzeDocument() }
                            .disabled(selectedFile == nil)
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                PDFFilePickerView(
                    title: "Select PDF",
                    allowsMultiple: false,
                    selectedFiles: $selectedFiles
                )
            }
            .onChange(of: selectedFiles) { _, _ in
                if let file = selectedFile {
                    outputName = "\(file.name) (redacted)"
                }
                // Reset analysis state when file changes
                detectedItems = []
                extractedText = ""
                didComplete = false
                resultFileName = nil
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
            .confettiOnComplete(didComplete)
        }
    }

    // MARK: - Analyze

    private func analyzeDocument() {
        guard let url = selectedFile?.fileURL else { return }
        isAnalyzing = true

        Task {
            do {
                let text = try await OCRService.shared.extractText(from: url)
                extractedText = text
                let matches = piiService.detectPII(in: text)

                detectedItems = matches.enumerated().map { index, match in
                    PIIItem(
                        id: "\(index)",
                        type: match.type,
                        originalValue: match.value,
                        maskedValue: piiService.maskValue(match.value, type: match.type),
                        range: match.range,
                        isSelected: true
                    )
                }

                if detectedItems.isEmpty {
                    HapticManager.success()
                } else {
                    HapticManager.medium()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.error()
            }
            isAnalyzing = false
        }
    }

    // MARK: - Redact

    private func redactDocument() {
        guard let url = selectedFile?.fileURL else { return }
        isRedacting = true

        Task {
            do {
                let result = try await performRedaction(sourceURL: url)
                resultFileName = result.lastPathComponent
                didComplete = true
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.error()
            }
            isRedacting = false
        }
    }

    private func performRedaction(sourceURL: URL) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: sourceURL) else {
            throw RedactError.cannotOpenPDF
        }

        let selectedMatches = detectedItems.filter(\.isSelected)
        guard !selectedMatches.isEmpty else {
            throw RedactError.noItemsSelected
        }

        // Collect the PII values to redact
        let valuesToRedact = selectedMatches.map(\.originalValue)
        var unresolvedMatches: Set<String> = []

        // Create a new PDF by rendering each page with redactions
        let redactedPDF = PDFDocument()

        for pageIndex in 0..<pdfDocument.pageCount {
          autoreleasepool {
            guard let page = pdfDocument.page(at: pageIndex) else { return }
            let pageBounds = page.bounds(for: .mediaBox)

            // Render the page to an image with redaction overlays
            let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
            let image = renderer.image { ctx in
                let cgContext = ctx.cgContext

                // Draw white background
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: pageBounds.size))

                // Draw the original PDF page
                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pageBounds.height)
                cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()

                // Find text locations on this page and draw black rectangles over PII.
                // Use selectionsByLine() so multi-line wrapped values get one box per visual line.
                if let pageText = page.string {
                    for value in valuesToRedact {
                        var searchRange = pageText.startIndex..<pageText.endIndex
                        while let foundRange = pageText.range(of: value, range: searchRange) {
                            let nsRange = NSRange(foundRange, in: pageText)
                            if let selection = page.selection(for: nsRange) {
                                let lineSelections = selection.selectionsByLine()
                                let segments = lineSelections.isEmpty ? [selection] : lineSelections
                                UIColor.black.setFill()
                                for seg in segments {
                                    let b = seg.bounds(for: page)
                                    guard b.width > 0, b.height > 0 else { continue }
                                    let uiRect = CGRect(
                                        x: b.origin.x,
                                        y: pageBounds.height - b.origin.y - b.height,
                                        width: b.width,
                                        height: b.height
                                    ).insetBy(dx: -2, dy: -1)
                                    ctx.fill(uiRect)
                                }
                            } else {
                                // Fail-safe: PDFKit couldn't map the range. Track for user warning.
                                unresolvedMatches.insert(value)
                            }
                            searchRange = foundRange.upperBound..<pageText.endIndex
                        }
                    }
                }
            }

            // Create a new PDF page from the rendered image
            if let cgImage = image.cgImage {
                let newPage = PDFPage(image: UIImage(cgImage: cgImage))
                if let newPage {
                    redactedPDF.insert(newPage, at: redactedPDF.pageCount)
                }
            }
          } // autoreleasepool
        }

        // Save the redacted PDF
        let sanitizedName = outputName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedName.isEmpty else { throw RedactError.saveFailed }

        let dir = FileStorageService.shared.appFilesDirectory
        var destinationURL = dir.appendingPathComponent("\(sanitizedName).pdf")
        var counter = 1
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            destinationURL = dir.appendingPathComponent("\(sanitizedName) (\(counter)).pdf")
            counter += 1
        }

        guard let data = redactedPDF.dataRepresentation() else {
            throw RedactError.saveFailed
        }

        // Abort if PDFKit couldn't locate any of the selected values — fail closed for security.
        if !unresolvedMatches.isEmpty {
            throw RedactError.partialRedaction(Array(unresolvedMatches))
        }

        try data.write(to: destinationURL)

        // Save to SwiftData
        let relativePath = AppConstants.appDocumentsSubdirectory + "/" + destinationURL.lastPathComponent
        let metadata = FileMetadataService.shared.extractMetadata(from: destinationURL)
        let docFile = DocumentFile(
            name: sanitizedName,
            fileExtension: "pdf",
            relativeFilePath: relativePath,
            fileSize: metadata.fileSize,
            pageCount: metadata.pageCount
        )
        modelContext.insert(docFile)
        try modelContext.save()

        return destinationURL
    }
}

// MARK: - PII Item Model

struct PIIItem: Identifiable {
    let id: String
    let type: PIIDetectionService.PIIType
    let originalValue: String
    let maskedValue: String
    let range: Range<String.Index>
    var isSelected: Bool
}

// MARK: - PII Item Row

private struct PIIItemRow: View {
    @Binding var item: PIIItem

    private var typeColor: Color {
        switch item.type.color {
        case "appDanger": return .appDanger
        case "appWarning": return .appWarning
        case "appAccent": return .appAccent
        case "appPrimary": return .appPrimary
        default: return .appTextMuted
        }
    }

    var body: some View {
        Button {
            item.isSelected.toggle()
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: item.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(typeColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.type.rawValue)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextMuted)
                    Text(item.maskedValue)
                        .font(.appBody)
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isSelected ? Color.appPrimary : Color.appTextDim)
                    .font(.system(size: 22))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Errors

private enum RedactError: LocalizedError {
    case cannotOpenPDF
    case noItemsSelected
    case saveFailed
    case partialRedaction([String])

    var errorDescription: String? {
        switch self {
        case .cannotOpenPDF: return "Cannot open the PDF file."
        case .noItemsSelected: return "No items selected for redaction."
        case .saveFailed: return "Failed to save the redacted PDF."
        case .partialRedaction(let values):
            let preview = values.prefix(2).joined(separator: ", ")
            return "Could not reliably locate \(values.count) item\(values.count == 1 ? "" : "s") (e.g. \(preview)). Redaction aborted to avoid leaking sensitive content. Try re-running OCR or rotate/flatten the PDF first."
        }
    }
}
