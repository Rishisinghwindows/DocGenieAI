import SwiftUI
import VisionKit
import SwiftData
import PDFKit

/// Real-time receipt scanner that detects receipt-like content via VisionKit's
/// DataScanner, then routes the captured image through OCR + Foundation Models
/// to produce a structured receipt the user can review and save.
struct SmartReceiptCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var capturedImage: UIImage?
    @State private var detectedHint: String?      // "Looks like a receipt" / "Detected text"
    @State private var isProcessing = false
    @State private var extracted: ReceiptData?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var didSave = false
    @State private var savedFileName: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(extracted == nil ? "Smart Receipt" : "Review")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    if let extracted, !didSave {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                save(extracted)
                            }
                            .bold()
                            .disabled(isProcessing)
                        }
                    }
                }
                .alert("Couldn't extract data", isPresented: $showError) {
                    Button("OK") {}
                } message: {
                    Text(errorMessage ?? "Try a sharper photo with the whole receipt in frame.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let extracted {
            ReviewView(receipt: extracted, image: capturedImage, didSave: didSave, savedFileName: savedFileName)
        } else if isProcessing {
            ProcessingView()
        } else if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            scanner
        } else {
            unsupportedView
        }
    }

    // MARK: - Scanner

    private var scanner: some View {
        ZStack(alignment: .bottom) {
            ReceiptDataScanner(
                onHint: { detectedHint = $0 },
                onCapture: { image in
                    capturedImage = image
                    Task { await extractReceipt(from: image) }
                }
            )
            .ignoresSafeArea()

            VStack(spacing: AppSpacing.sm) {
                if let detectedHint {
                    Label(detectedHint, systemImage: "sparkles")
                        .font(.appCaption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(.black.opacity(0.65), in: Capsule())
                }
                Text("Hold the receipt flat in good light. Olea extracts merchant, total, and date.")
                    .font(.appMicro)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
            }
            .padding(.bottom, AppSpacing.md)
        }
    }

    private var unsupportedView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 56))
                .foregroundStyle(Color.appTextDim)
            Text("Camera not available")
                .font(.appH3)
                .foregroundStyle(Color.appText)
            Text("Smart Receipt requires camera access on a real device.")
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .padding()
    }

    // MARK: - Processing

    private struct ProcessingView: View {
        var body: some View {
            VStack(spacing: AppSpacing.md) {
                ProgressView().scaleEffect(1.4).tint(Color.appPrimary)
                Text("Reading the receipt…")
                    .font(.appBody)
                    .foregroundStyle(Color.appTextMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Extraction

    private func extractReceipt(from image: UIImage) async {
        isProcessing = true
        defer { isProcessing = false }

        // Persist the image as a JPEG so OCR can read from a URL — matches the
        // rest of the OCR pipeline and gives us a DocumentFile to save.
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            errorMessage = "Image encoding failed."
            showError = true
            return
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("receipt_\(UUID().uuidString).jpg")
        do {
            try data.write(to: tempURL)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return
        }

        let ocr: String
        do {
            ocr = try await OCRService.shared.extractText(from: tempURL)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return
        }

        guard !ocr.isEmpty else {
            errorMessage = "Couldn't read any text from this image."
            showError = true
            return
        }

        let parsed = ScanContentType.parseReceipt(ocrText: ocr)
        extracted = parsed
        capturedImage = image
        HapticManager.success()
    }

    // MARK: - Save

    private func save(_ receipt: ReceiptData) {
        guard let image = capturedImage,
              let data = image.jpegData(compressionQuality: 0.85) else { return }

        let baseName = receipt.vendor.isEmpty || receipt.vendor == "Unknown"
            ? "Receipt"
            : "Receipt - \(receipt.vendor)"
        let dateStr = receipt.date ?? ""
        let suggested = dateStr.isEmpty ? baseName : "\(baseName) \(dateStr)"
        let fileName = "\(suggested).jpg"
        let destinationURL = FileStorageService.shared.appFilesDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: destinationURL)
            let relativePath = "\(AppConstants.appDocumentsSubdirectory)/\(fileName)"
            let docFile = DocumentFile(
                name: suggested,
                fileExtension: "jpg",
                relativeFilePath: relativePath,
                fileSize: Int64(data.count)
            )
            docFile.tagName = FileTag.receipt.rawValue
            docFile.aiSuggestedName = suggested
            docFile.aiContentType = "receipt"
            docFile.aiSummary = receipt.formattedSummary
            docFile.aiOrganizedAt = .now
            docFile.aiNeedsReview = false
            modelContext.insert(docFile)
            try modelContext.save()
            didSave = true
            savedFileName = suggested
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Review

private struct ReviewView: View {
    let receipt: ReceiptData
    let image: UIImage?
    let didSave: Bool
    let savedFileName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AppCornerRadius.md).stroke(Color.appBorder, lineWidth: 0.5))
                }

                if didSave, let savedFileName {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.appSuccess)
                        Text("Saved as \(savedFileName)")
                            .font(.appBody.bold())
                            .foregroundStyle(Color.appSuccess)
                    }
                    .padding(.vertical, AppSpacing.sm)
                }

                ReviewRow(label: "Merchant", value: receipt.vendor.isEmpty ? "—" : receipt.vendor)
                ReviewRow(label: "Total", value: receipt.total ?? "—")
                ReviewRow(label: "Date", value: receipt.date ?? "—")
                if !receipt.items.isEmpty {
                    Text("Items")
                        .font(.appCaption.bold())
                        .foregroundStyle(Color.appTextMuted)
                        .padding(.top, AppSpacing.sm)
                    ForEach(Array(receipt.items.enumerated()), id: \.offset) { _, item in
                        Text(item)
                            .font(.appCaption)
                            .foregroundStyle(Color.appText)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(Color.appBGDark.ignoresSafeArea())
    }
}

private struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.appMicro)
                .tracking(1)
                .foregroundStyle(Color.appTextDim)
            Text(value)
                .font(.appBody.bold())
                .foregroundStyle(Color.appText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))
    }
}

// MARK: - DataScanner UIViewController bridge

private struct ReceiptDataScanner: UIViewControllerRepresentable {
    let onHint: (String?) -> Void
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onHint: onHint, onCapture: onCapture) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(textContentType: nil)],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onHint: (String?) -> Void
        let onCapture: (UIImage) -> Void
        private var hasCaptured = false

        init(onHint: @escaping (String?) -> Void, onCapture: @escaping (UIImage) -> Void) {
            self.onHint = onHint
            self.onCapture = onCapture
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasCaptured else { return }
            // Simple heuristic: 6+ distinct text items in frame + price-like tokens → likely a receipt.
            let textCount = allItems.compactMap { item -> String? in
                if case .text(let t) = item { return t.transcript } else { return nil }
            }
            let joined = textCount.joined(separator: " ")
            let priceHits = Self.countPriceTokens(in: joined)
            if textCount.count >= 6 && priceHits >= 2 {
                onHint("Looks like a receipt — hold steady")
                Task { @MainActor in
                    hasCaptured = true
                    if let image = try? await dataScanner.capturePhoto() {
                        onCapture(image)
                    } else {
                        hasCaptured = false
                    }
                }
            } else if !textCount.isEmpty {
                onHint("Detecting text…")
            }
        }

        static func countPriceTokens(in text: String) -> Int {
            guard let regex = try? NSRegularExpression(pattern: #"\$?\d+\.\d{2}"#) else { return 0 }
            let range = NSRange(text.startIndex..., in: text)
            return regex.numberOfMatches(in: text, range: range)
        }
    }
}
