import SwiftUI
import SwiftData

// MARK: - Image Category

enum ImageGallerySegment: String, CaseIterable, Identifiable {
    case all = "All"
    case documents = "Documents"
    case people = "People"
    case other = "Other"

    var id: String { rawValue }
}

// MARK: - Gallery View

struct ImageGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DocumentFile.importedAt, order: .reverse) private var allFiles: [DocumentFile]

    @State private var searchText = ""
    @State private var selectedSegment: ImageGallerySegment = .all
    @State private var selectedImage: DocumentFile?
    @State private var showEditor = false
    @State private var editorImage: DocumentFile?
    @State private var classifications: [UUID: ImageClassification] = [:]
    @State private var isClassifying = false
    @State private var showDeleteConfirmation = false
    @State private var fileToDelete: DocumentFile?

    private var imageFiles: [DocumentFile] {
        allFiles.filter { FileCategory.img.extensions.contains($0.fileExtension.lowercased()) }
    }

    private var filteredImages: [DocumentFile] {
        var result = imageFiles

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply segment filter
        switch selectedSegment {
        case .all:
            break
        case .documents:
            result = result.filter { classifications[$0.id]?.isDocument == true }
        case .people:
            result = result.filter { (classifications[$0.id]?.faceCount ?? 0) > 0 }
        case .other:
            result = result.filter {
                let info = classifications[$0.id]
                return info?.isDocument != true && (info?.faceCount ?? 0) == 0
            }
        }

        return result
    }

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.xs),
        GridItem(.flexible(), spacing: AppSpacing.xs),
        GridItem(.flexible(), spacing: AppSpacing.xs)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    // Search bar
                    AppSearchBar(text: $searchText, placeholder: "Search images...")
                        .padding(.horizontal, AppSpacing.md)

                    // Segment picker
                    Picker("Filter", selection: $selectedSegment) {
                        ForEach(ImageGallerySegment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.md)

                    // Stats bar
                    HStack {
                        Text("\(filteredImages.count) images")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextMuted)
                        Spacer()
                        if isClassifying {
                            HStack(spacing: AppSpacing.xs) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Analyzing...")
                                    .font(.appMicro)
                                    .foregroundStyle(Color.appTextDim)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)

                    if filteredImages.isEmpty {
                        EmptyStateView(
                            icon: "photo.on.rectangle.angled",
                            title: "No Images",
                            message: selectedSegment == .all
                                ? "Import some images to see them here."
                                : "No images match this filter."
                        )
                        .frame(minHeight: 300)
                    } else {
                        // Image grid
                        LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
                            ForEach(Array(filteredImages.enumerated()), id: \.element.id) { index, file in
                                ImageThumbnailCell(
                                    file: file,
                                    classification: classifications[file.id]
                                )
                                .staggeredAppear(index: index)
                                .onTapGesture {
                                    HapticManager.light()
                                    selectedImage = file
                                }
                                .contextMenu {
                                    contextMenuContent(for: file)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.xs)
                    }
                }
                .padding(.vertical, AppSpacing.sm)
            }
            .background(Color.appBGDark)
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
            }
            .fullScreenCover(item: $selectedImage) { file in
                FullScreenImageViewer(file: file, classification: classifications[file.id])
            }
            .sheet(item: $editorImage) { file in
                ImageEditorView(file: file)
            }
            .alert("Delete Image?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { fileToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let file = fileToDelete {
                        deleteFile(file)
                    }
                    fileToDelete = nil
                }
            } message: {
                Text("This will permanently remove \"\(fileToDelete?.fullFileName ?? "")\".")
            }
            .task {
                await classifyAllImages()
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuContent(for file: DocumentFile) -> some View {
        Button {
            editorImage = file
        } label: {
            Label("Enhance", systemImage: "wand.and.stars")
        }

        Button {
            // Snapshot the @Model fields synchronously at tap time so the async work
            // doesn't re-touch a possibly-faulted persistent object.
            let url = file.fileURL
            let id = file.id
            let name = file.name
            Task { await removeBackground(url: url, fileID: id, fileName: name) }
        } label: {
            Label("Remove Background", systemImage: "person.crop.rectangle")
        }

        Button {
            let url = file.fileURL
            Task { await extractText(url: url) }
        } label: {
            Label("Extract Text", systemImage: "doc.text.viewfinder")
        }

        Button {
            if let url = file.fileURL {
                ShareService.shared.share(fileURL: url)
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            fileToDelete = file
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func classifyAllImages() async {
        guard !isClassifying else { return }
        isClassifying = true
        let service = ImageIntelligenceService.shared

        // Collect file info on MainActor, then process off-main
        let filesToClassify = imageFiles.filter { classifications[$0.id] == nil }
            .compactMap { file -> (UUID, URL)? in
                guard let url = file.fileURL else { return nil }
                return (file.id, url)
            }

        for (fileId, url) in filesToClassify {
            // Run Vision work on a detached task to avoid MainActor isolation issues
            let result = await Task.detached(priority: .utility) {
                let isDoc = await service.isDocument(at: url)
                let faces = await service.detectFaces(at: url)
                let labels = await service.classifyImage(at: url)
                return ImageClassification(isDocument: isDoc, faceCount: faces, labels: labels)
            }.value

            classifications[fileId] = result
        }
        isClassifying = false
    }

    private func removeBackground(url: URL?, fileID: UUID, fileName: String) async {
        guard let url, let image = UIImage(contentsOfFile: url.path) else { return }
        guard let result = await ImageIntelligenceService.shared.removeBackground(from: image) else { return }
        saveProcessedImage(result, originalFileID: fileID, originalFileName: fileName, suffix: "nobg")
    }

    private func extractText(url: URL?) async {
        guard let url else { return }
        let text = try? await OCRService.shared.extractText(from: url)
        if let text, !text.isEmpty {
            UIPasteboard.general.string = text
            HapticManager.success()
        }
    }

    private func deleteFile(_ file: DocumentFile) {
        try? FileStorageService.shared.deleteFile(at: file.relativeFilePath)
        modelContext.delete(file)
        try? modelContext.save()
        HapticManager.medium()
    }

    private func saveProcessedImage(_ image: UIImage, originalFileID: UUID, originalFileName: String, suffix: String) {
        guard let data = image.pngData() else { return }
        let fileName = "\(originalFileName)_\(suffix).png"
        let destinationURL = FileStorageService.shared.appFilesDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: destinationURL)
            let relativePath = "\(AppConstants.appDocumentsSubdirectory)/\(fileName)"
            let newFile = DocumentFile(
                name: "\(originalFileName)_\(suffix)",
                fileExtension: "png",
                relativeFilePath: relativePath,
                fileSize: Int64(data.count)
            )
            modelContext.insert(newFile)
            try modelContext.save()
            HapticManager.success()
        } catch {
            HapticManager.error()
        }
    }
}

// MARK: - Classification Model

struct ImageClassification {
    let isDocument: Bool
    let faceCount: Int
    let labels: [String]
}

// MARK: - Thumbnail Cell

private struct ImageThumbnailCell: View {
    let file: DocumentFile
    let classification: ImageClassification?
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.appBGCard)
                    .frame(minHeight: 120)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(Color.appTextDim)
                    }
            }

            // Badge overlay
            if let classification {
                HStack(spacing: 2) {
                    if classification.isDocument {
                        badgeIcon("doc.text", color: .appAccent)
                    }
                    if classification.faceCount > 0 {
                        badgeIcon("person.fill", color: .appSuccess)
                    }
                }
                .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                .stroke(Color.appBorder.opacity(0.3), lineWidth: 0.5)
        )
        // Snapshot the URL via capture list at body-time, then load a downsampled
        // thumbnail off the main thread. Avoids decoding multi-MB JPEGs synchronously.
        .task { [url = file.fileURL] in
            guard let url, thumbnail == nil else { return }
            thumbnail = await Task.detached(priority: .utility) {
                Self.downsample(url: url, maxPixelSize: 240)
            }.value
        }
    }

    private func badgeIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background(color.opacity(0.85), in: Circle())
    }

    private nonisolated static func downsample(url: URL, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Full Screen Image Viewer

struct FullScreenImageViewer: View {
    let file: DocumentFile
    let classification: ImageClassification?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var fullImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let uiImage = fullImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = max(1.0, value.magnification)
                                }
                                .onEnded { _ in
                                    withAnimation(.spring()) {
                                        if scale < 1.2 { scale = 1.0; offset = .zero }
                                    }
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            if scale > 1.0 {
                                                offset = value.translation
                                            }
                                        }
                                        .onEnded { _ in
                                            if scale <= 1.0 {
                                                withAnimation(.spring()) { offset = .zero }
                                            }
                                        }
                                )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                } else {
                                    scale = 3.0
                                }
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = file.fileURL {
                        Button {
                            ShareService.shared.share(fileURL: url)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    VStack(spacing: 2) {
                        Text(file.fullFileName)
                            .font(.appCaption)
                            .foregroundStyle(.white)
                        if let classification, !classification.labels.isEmpty {
                            Text(classification.labels.prefix(3).joined(separator: " - "))
                                .font(.appMicro)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .bottomBar)
            // Load full-size image off-main, downsampled to a sensible viewport size
            // so a 30 MP photo doesn't decode 4× on the main thread.
            .task { [url = file.fileURL] in
                guard let url, fullImage == nil else { return }
                fullImage = await Task.detached(priority: .userInitiated) {
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return UIImage(contentsOfFile: url.path) }
                    let opts: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceShouldCacheImmediately: true,
                        kCGImageSourceThumbnailMaxPixelSize: 2048
                    ]
                    guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else {
                        return UIImage(contentsOfFile: url.path)
                    }
                    return UIImage(cgImage: cg)
                }.value
            }
        }
    }
}
