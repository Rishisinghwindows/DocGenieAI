import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct QRShareView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFiles: [DocumentFile] = []
    @State private var showPicker = false
    @State private var qrImage: UIImage?
    @State private var didSaveQR = false
    @State private var showShareSheet = false
    @State private var showError = false
    @State private var errorMessage: String?

    private var selectedFile: DocumentFile? { selectedFiles.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Select File") {
                    Button {
                        showPicker = true
                    } label: {
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
                            Label("Choose a file", systemImage: "doc.richtext")
                                .font(.appBody)
                        }
                    }
                }

                if let file = selectedFile {
                    Section("File Details") {
                        LabeledContent {
                            Text(file.fullFileName)
                                .font(.appCaption)
                                .foregroundStyle(Color.appText)
                        } label: {
                            Text("Name")
                                .font(.appBody)
                                .foregroundStyle(Color.appTextMuted)
                        }

                        LabeledContent {
                            Text(file.fileSize.formattedFileSize)
                                .font(.appCaption)
                                .foregroundStyle(Color.appText)
                        } label: {
                            Text("Size")
                                .font(.appBody)
                                .foregroundStyle(Color.appTextMuted)
                        }

                        if let pageCount = file.pageCount, pageCount > 0 {
                            LabeledContent {
                                Text("\(pageCount) pages")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.appText)
                            } label: {
                                Text("Pages")
                                    .font(.appBody)
                                    .foregroundStyle(Color.appTextMuted)
                            }
                        }
                    }
                }

                if let qrImage {
                    Section("QR Code") {
                        VStack(spacing: AppSpacing.md) {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 240, maxHeight: 240)
                                .padding(AppSpacing.md)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md))
                                .frame(maxWidth: .infinity)

                            Text("Scan to view file info")
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextMuted)
                        }
                        .listRowBackground(Color.appBGCard)
                    }

                    Section {
                        Button {
                            saveQRToPhotos()
                        } label: {
                            Label("Save QR Code to Photos", systemImage: "square.and.arrow.down")
                                .font(.appBody)
                                .foregroundStyle(Color.appPrimary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share File & QR Code", systemImage: "square.and.arrow.up")
                                .font(.appBody)
                                .foregroundStyle(Color.appAccent)
                        }
                        .buttonStyle(.plain)
                    }

                    if didSaveQR {
                        Section {
                            VStack(spacing: AppSpacing.sm) {
                                AnimatedCheckmark()
                                Text("QR code saved to Photos")
                                    .font(.appBody)
                                    .foregroundStyle(Color.appSuccess)
                            }
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.appSuccess.opacity(0.05))
                        }
                    }
                }
            }
            .navigationTitle("QR Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if didSaveQR {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Generate") { generateQRCode() }
                            .disabled(selectedFile == nil)
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                PDFFilePickerView(
                    title: "Select File",
                    allowsMultiple: false,
                    selectedFiles: $selectedFiles
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let items = shareItems() {
                    ActivityViewController(activityItems: items)
                }
            }
            .onChange(of: selectedFiles) { _, _ in
                qrImage = nil
                didSaveQR = false
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
            .confettiOnComplete(didSaveQR)
        }
    }

    // MARK: - QR Code Generation

    private func generateQRCode() {
        guard let file = selectedFile else { return }
        HapticManager.medium()

        var payload = "DocGenieAI File\n"
        payload += "Name: \(file.fullFileName)\n"
        payload += "Size: \(file.fileSize.formattedFileSize)\n"
        if let pageCount = file.pageCount, pageCount > 0 {
            payload += "Pages: \(pageCount)\n"
        }

        guard let data = payload.data(using: .utf8) else {
            errorMessage = "Failed to encode file metadata."
            showError = true
            return
        }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            errorMessage = "Failed to generate QR code."
            showError = true
            return
        }

        // Scale QR code up for crisp rendering
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: scale)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            errorMessage = "Failed to render QR code image."
            showError = true
            return
        }

        withAnimation {
            qrImage = UIImage(cgImage: cgImage)
        }
        HapticManager.success()
    }

    // MARK: - Save to Photos

    private func saveQRToPhotos() {
        guard let qrImage else { return }
        HapticManager.medium()

        UIImageWriteToSavedPhotosAlbum(qrImage, nil, nil, nil)
        withAnimation {
            didSaveQR = true
        }
        HapticManager.success()
    }

    // MARK: - Share

    private func shareItems() -> [Any]? {
        var items: [Any] = []

        if let qrImage {
            items.append(qrImage)
        }

        if let url = selectedFile?.fileURL {
            items.append(url)
        }

        return items.isEmpty ? nil : items
    }
}

// MARK: - UIActivityViewController wrapper

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
