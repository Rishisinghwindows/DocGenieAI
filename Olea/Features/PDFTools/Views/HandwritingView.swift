import SwiftUI
import SwiftData
import Vision
import PDFKit

struct HandwritingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DocumentFile.importedAt, order: .reverse) private var allFiles: [DocumentFile]
    @State private var selectedFile: DocumentFile?
    @State private var showPicker = false
    @State private var isProcessing = false
    @State private var extractedText: String?
    @State private var previewImage: UIImage?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var didComplete = false
    @State private var resultFileName: String?
    @State private var showCopied = false

    private var selectableFiles: [DocumentFile] {
        allFiles.filter {
            ["pdf", "jpg", "jpeg", "png", "heic", "tiff", "bmp"].contains($0.fileExtension.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if extractedText == nil && !isProcessing {
                    Form {
                        Section("Select File") {
                            Button { showPicker = true } label: {
                                if let file = selectedFile {
                                    HStack {
                                        FileTypeIcon(fileExtension: file.fileExtension)
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
                                    Label("Choose an image or PDF", systemImage: "hand.draw")
                                        .font(.appBody)
                                }
                            }
                        }

                        Section {
                            Text("Select an image or scanned PDF containing handwriting. Enhanced recognition uses accurate mode with language correction.")
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextMuted)
                        }
                    }
                } else if isProcessing {
                    VStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Recognizing handwriting...")
                            .font(.appBody)
                            .foregroundStyle(Color.appTextMuted)
                        Text("Using enhanced accuracy mode")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBGDark)
                } else if let text = extractedText {
                    if text.isEmpty {
                        EmptyStateView(
                            icon: "hand.draw",
                            title: "No Handwriting Found",
                            message: "No readable handwriting was detected in this file."
                        )
                    } else {
                        resultView(text: text)
                    }
                }
            }
            .navigationTitle("Handwriting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if extractedText == nil && !isProcessing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Recognize") { recognizeHandwriting() }
                            .disabled(selectedFile == nil)
                    }
                }
                if let text = extractedText, !text.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Menu {
                            Button {
                                copyText()
                            } label: {
                                Label("Copy Text", systemImage: "doc.on.doc")
                            }
                            Button {
                                saveAsTextFile()
                            } label: {
                                Label("Save as Text File", systemImage: "doc.text")
                            }
                            Button {
                                saveAsPDF()
                            } label: {
                                Label("Save as PDF", systemImage: "doc.richtext")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                HandwritingFilePickerSheet(files: selectableFiles, selectedFile: $selectedFile)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
            .overlay {
                if showCopied {
                    VStack {
                        Spacer()
                        Text("Copied to clipboard")
                            .font(.appCaption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(Color.appSuccess, in: Capsule())
                            .padding(.bottom, AppSpacing.xl)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: showCopied)
                }
            }
            .confettiOnComplete(didComplete)
        }
    }

    // MARK: - Result View

    private func resultView(text: String) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                // Preview image if available
                if let image = previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                                .stroke(Color.appTextDim.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, AppSpacing.md)
                }

                // Extracted text section
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundStyle(Color.appAccent)
                        Text("Recognized Text")
                            .font(.appH3)
                            .foregroundStyle(Color.appText)
                        Spacer()
                        Text("\(text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count) words")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextMuted)
                    }
                    .padding(.horizontal, AppSpacing.md)

                    Text(text)
                        .font(.appBody)
                        .foregroundStyle(Color.appText)
                        .textSelection(.enabled)
                        .padding(AppSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
                        .padding(.horizontal, AppSpacing.md)
                }

                if didComplete, let name = resultFileName {
                    VStack(spacing: AppSpacing.sm) {
                        AnimatedCheckmark()
                        Text("Saved as \(name)")
                            .font(.appBody)
                            .foregroundStyle(Color.appSuccess)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.md)
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(Color.appBGDark)
    }

    // MARK: - Recognize Handwriting

    private func recognizeHandwriting() {
        guard let url = selectedFile?.fileURL else { return }
        isProcessing = true

        Task {
            do {
                let images = try loadImages(from: url)
                if let firstImage = images.first {
                    previewImage = firstImage
                }

                var allText = ""
                for image in images {
                    let text = try await recognizeText(in: image)
                    if !text.isEmpty {
                        if !allText.isEmpty { allText += "\n\n" }
                        allText += text
                    }
                }

                extractedText = allText
                if allText.isEmpty {
                    HapticManager.error()
                } else {
                    HapticManager.success()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.error()
            }
            isProcessing = false
        }
    }

    private func loadImages(from url: URL) throws -> [UIImage] {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            guard let document = PDFDocument(url: url) else {
                throw HandwritingError.cannotOpenFile
            }
            var images: [UIImage] = []
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                let scale: CGFloat = 2.0
                let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                    ctx.cgContext.scaleBy(x: scale, y: scale)
                    ctx.cgContext.translateBy(x: 0, y: bounds.height)
                    ctx.cgContext.scaleBy(x: 1, y: -1)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                images.append(image)
            }
            return images
        } else {
            guard let image = UIImage(contentsOfFile: url.path) else {
                throw HandwritingError.cannotOpenFile
            }
            return [image]
        }
    }

    private func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw HandwritingError.cannotOpenFile
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Actions

    private func copyText() {
        UIPasteboard.general.string = extractedText ?? ""
        HapticManager.light()
        withAnimation {
            showCopied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showCopied = false
            }
        }
    }

    private func saveAsTextFile() {
        guard let text = extractedText, !text.isEmpty else { return }

        let fileName = selectedFile?.name ?? "Handwriting"
        let sanitizedName = "\(fileName) (text)"
        let dir = FileStorageService.shared.appFilesDirectory

        var destinationURL = dir.appendingPathComponent("\(sanitizedName).txt")
        var counter = 1
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            destinationURL = dir.appendingPathComponent("\(sanitizedName) (\(counter)).txt")
            counter += 1
        }

        do {
            try text.write(to: destinationURL, atomically: true, encoding: .utf8)

            let relativePath = AppConstants.appDocumentsSubdirectory + "/" + destinationURL.lastPathComponent
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0
            let docFile = DocumentFile(
                name: sanitizedName,
                fileExtension: "txt",
                relativeFilePath: relativePath,
                fileSize: fileSize
            )
            modelContext.insert(docFile)
            try modelContext.save()

            resultFileName = destinationURL.lastPathComponent
            didComplete = true
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.error()
        }
    }

    private func saveAsPDF() {
        guard let text = extractedText, !text.isEmpty else { return }

        let fileName = selectedFile?.name ?? "Handwriting"
        let sanitizedName = "\(fileName) (typed)"
        let dir = FileStorageService.shared.appFilesDirectory

        var destinationURL = dir.appendingPathComponent("\(sanitizedName).pdf")
        var counter = 1
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            destinationURL = dir.appendingPathComponent("\(sanitizedName) (\(counter)).pdf")
            counter += 1
        }

        do {
            // Create a typed PDF from the extracted text
            let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
            let textMargin: CGFloat = 50
            let textRect = pageRect.insetBy(dx: textMargin, dy: textMargin)

            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
            let data = renderer.pdfData { context in
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 4
                paragraphStyle.paragraphSpacing = 8

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle
                ]

                let attrString = NSAttributedString(string: text, attributes: attributes)
                let framesetter = CTFramesetterCreateWithAttributedString(attrString)
                var currentIndex = 0
                let totalLength = attrString.length

                while currentIndex < totalLength {
                    context.beginPage()

                    let path = CGPath(rect: textRect, transform: nil)
                    let frameRange = CFRangeMake(currentIndex, 0)
                    let frame = CTFramesetterCreateFrame(framesetter, frameRange, path, nil)

                    let cgContext = context.cgContext
                    cgContext.saveGState()
                    cgContext.translateBy(x: 0, y: pageRect.height)
                    cgContext.scaleBy(x: 1, y: -1)

                    CTFrameDraw(frame, cgContext)
                    cgContext.restoreGState()

                    let visibleRange = CTFrameGetVisibleStringRange(frame)
                    currentIndex += visibleRange.length

                    if visibleRange.length == 0 { break }
                }
            }

            try data.write(to: destinationURL)

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

            resultFileName = destinationURL.lastPathComponent
            didComplete = true
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.error()
        }
    }
}

// MARK: - File Picker Sheet

private struct HandwritingFilePickerSheet: View {
    let files: [DocumentFile]
    @Binding var selectedFile: DocumentFile?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if files.isEmpty {
                    EmptyStateView(
                        icon: "hand.draw",
                        title: "No Files",
                        message: "Import images or scanned PDFs first."
                    )
                } else {
                    List(files) { file in
                        Button {
                            selectedFile = file
                            dismiss()
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                FileTypeIcon(fileExtension: file.fileExtension)
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text(file.fullFileName)
                                        .font(.appBody)
                                        .foregroundStyle(Color.appText)
                                        .lineLimit(1)
                                    Text(file.fileSize.formattedFileSize)
                                        .font(.appCaption)
                                        .foregroundStyle(Color.appTextDim)
                                }
                                Spacer()
                                if selectedFile?.id == file.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.appPrimary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Errors

private enum HandwritingError: LocalizedError {
    case cannotOpenFile

    var errorDescription: String? {
        switch self {
        case .cannotOpenFile: return "Cannot open the selected file."
        }
    }
}
