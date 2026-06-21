import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Filter Type

enum ImageFilterType: String, CaseIterable, Identifiable {
    case original = "Original"
    case autoEnhance = "Auto"
    case blackAndWhite = "B&W"
    case sepia = "Sepia"
    case vivid = "Vivid"
    case documentMode = "Document"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .original: return "photo"
        case .autoEnhance: return "wand.and.stars"
        case .blackAndWhite: return "circle.lefthalf.filled"
        case .sepia: return "sun.min"
        case .vivid: return "sparkles"
        case .documentMode: return "doc.text"
        }
    }
}

// MARK: - Image Editor View

struct ImageEditorView: View {
    let file: DocumentFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var originalImage: UIImage?
    @State private var displayImage: UIImage?
    @State private var brightness: Double = 0.0
    @State private var contrast: Double = 1.0
    @State private var saturation: Double = 1.0
    @State private var selectedFilter: ImageFilterType = .original
    @State private var isRemovingBackground = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showCrop = false
    @State private var isProcessing = false

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBGDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Image preview
                    imagePreview
                        .frame(maxHeight: .infinity)

                    // Controls
                    VStack(spacing: AppSpacing.md) {
                        // Filter strip
                        filterStrip

                        // Adjustment sliders
                        adjustmentSliders

                        // Action buttons
                        actionButtons
                    }
                    .padding(AppSpacing.md)
                    .background(Color.appBGCard)
                }

                // Save success overlay
                if showSaveSuccess {
                    saveSuccessOverlay
                }
            }
            .navigationTitle("Edit Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appTextMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") { resetAdjustments() }
                        .foregroundStyle(Color.appWarning)
                }
            }
            .task {
                loadImage()
            }
            .sheet(isPresented: $showCrop) {
                if let image = displayImage ?? originalImage {
                    CropView(image: image) { cropped in
                        originalImage = cropped
                        applyCurrentAdjustments()
                    }
                }
            }
        }
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        Group {
            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md))
                    .padding(AppSpacing.md)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Filter Strip

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(ImageFilterType.allCases) { filter in
                    filterButton(for: filter)
                }
            }
        }
    }

    private func filterButton(for filter: ImageFilterType) -> some View {
        Button {
            HapticManager.selection()
            selectedFilter = filter
            applyFilter(filter)
        } label: {
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                        .fill(selectedFilter == filter ? Color.appPrimary.opacity(0.2) : Color.appBGDark)
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                .stroke(selectedFilter == filter ? Color.appPrimary : Color.appBorder, lineWidth: selectedFilter == filter ? 2 : 1)
                        )

                    Image(systemName: filter.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(selectedFilter == filter ? Color.appPrimary : Color.appTextMuted)
                }

                Text(filter.rawValue)
                    .font(.appMicro)
                    .foregroundStyle(selectedFilter == filter ? Color.appPrimary : Color.appTextMuted)
            }
        }
    }

    // MARK: - Adjustment Sliders

    private var adjustmentSliders: some View {
        VStack(spacing: AppSpacing.sm) {
            sliderRow(label: "Brightness", value: $brightness, range: -0.5...0.5, icon: "sun.max")
            sliderRow(label: "Contrast", value: $contrast, range: 0.5...2.0, icon: "circle.lefthalf.filled")
            sliderRow(label: "Saturation", value: $saturation, range: 0.0...2.0, icon: "drop.halffull")
        }
        .onChange(of: brightness) { _, _ in applyCurrentAdjustments() }
        .onChange(of: contrast) { _, _ in applyCurrentAdjustments() }
        .onChange(of: saturation) { _, _ in applyCurrentAdjustments() }
    }

    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, icon: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.appCaption)
                .foregroundStyle(Color.appTextMuted)
                .frame(width: 20)

            Text(label)
                .font(.appMicro)
                .foregroundStyle(Color.appTextMuted)
                .frame(width: 70, alignment: .leading)

            Slider(value: value, in: range)
                .tint(Color.appPrimary)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: AppSpacing.md) {
            // Remove Background
            Button {
                Task { await removeBackground() }
            } label: {
                Label("Remove BG", systemImage: "person.crop.rectangle")
                    .font(.appCaption)
                    .foregroundStyle(Color.appText)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.appBGDark, in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
            }
            .disabled(isRemovingBackground)
            .opacity(isRemovingBackground ? 0.5 : 1)

            // Crop
            Button {
                showCrop = true
            } label: {
                Label("Crop", systemImage: "crop")
                    .font(.appCaption)
                    .foregroundStyle(Color.appText)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.appBGDark, in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
            }

            Spacer()

            // Save
            Button {
                Task { await saveImage() }
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.appPrimary, in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))
            }
            .disabled(isSaving)
        }
    }

    // MARK: - Save Success Overlay

    private var saveSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.md) {
                AnimatedCheckmark(size: 80)
                Text("Saved!")
                    .font(.appH2)
                    .foregroundStyle(Color.appText)
            }
        }
        .confettiOnComplete(showSaveSuccess)
        .transition(.opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showSaveSuccess = false }
                dismiss()
            }
        }
    }

    // MARK: - Logic

    private func loadImage() {
        guard let url = file.fileURL else { return }
        originalImage = UIImage(contentsOfFile: url.path)
        displayImage = originalImage
    }

    private func resetAdjustments() {
        brightness = 0.0
        contrast = 1.0
        saturation = 1.0
        selectedFilter = .original
        displayImage = originalImage
        HapticManager.light()
    }

    private func applyCurrentAdjustments() {
        guard let original = originalImage,
              let ciImage = CIImage(image: original) else { return }

        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.brightness = Float(brightness)
        filter.contrast = Float(contrast)
        filter.saturation = Float(saturation)

        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else { return }

        displayImage = UIImage(cgImage: cgImage, scale: original.scale, orientation: original.imageOrientation)
    }

    private func applyFilter(_ filterType: ImageFilterType) {
        guard let original = originalImage else { return }
        isProcessing = true

        Task {
            let result: UIImage?
            switch filterType {
            case .original:
                brightness = 0.0
                contrast = 1.0
                saturation = 1.0
                result = original
            case .autoEnhance:
                result = ImageIntelligenceService.shared.autoEnhance(image: original)
            case .blackAndWhite:
                result = applyColorControlsFilter(to: original, brightness: 0, contrast: 1.1, saturation: 0)
            case .sepia:
                result = applySepiaFilter(to: original)
            case .vivid:
                result = applyColorControlsFilter(to: original, brightness: 0.05, contrast: 1.3, saturation: 1.5)
            case .documentMode:
                result = await ImageIntelligenceService.shared.enhanceDocument(image: original)
            }

            displayImage = result ?? original
            isProcessing = false
        }
    }

    private func applyColorControlsFilter(to image: UIImage, brightness: Float, contrast: Float, saturation: Float) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.brightness = brightness
        filter.contrast = contrast
        filter.saturation = saturation
        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func applySepiaFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.sepiaTone()
        filter.inputImage = ciImage
        filter.intensity = 0.8
        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func removeBackground() async {
        guard let image = displayImage ?? originalImage else { return }
        isRemovingBackground = true
        if let result = await ImageIntelligenceService.shared.removeBackground(from: image) {
            displayImage = result
            originalImage = result
            HapticManager.success()
        } else {
            HapticManager.error()
        }
        isRemovingBackground = false
    }

    private func saveImage() async {
        guard let image = displayImage else { return }
        isSaving = true

        let data: Data?
        let ext: String
        if file.fileExtension.lowercased() == "png" || displayImage != originalImage {
            data = image.pngData()
            ext = "png"
        } else {
            data = image.jpegData(compressionQuality: 0.9)
            ext = "jpg"
        }

        guard let imageData = data else {
            isSaving = false
            HapticManager.error()
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(file.name)_edited_\(timestamp).\(ext)"
        let destinationURL = FileStorageService.shared.appFilesDirectory.appendingPathComponent(fileName)

        do {
            try imageData.write(to: destinationURL)
            let relativePath = "\(AppConstants.appDocumentsSubdirectory)/\(fileName)"
            let newFile = DocumentFile(
                name: "\(file.name)_edited_\(timestamp)",
                fileExtension: ext,
                relativeFilePath: relativePath,
                fileSize: Int64(imageData.count)
            )
            modelContext.insert(newFile)
            try modelContext.save()

            isSaving = false
            withAnimation { showSaveSuccess = true }
        } catch {
            isSaving = false
            HapticManager.error()
        }
    }
}

// MARK: - Crop View

struct CropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var cropRect: CGRect = .zero
    @State private var imageFrame: CGRect = .zero
    @State private var dragStart: CGPoint = .zero
    @State private var isDragging = false
    @State private var activeHandle: CropHandle = .none

    enum CropHandle {
        case none, topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geo in
                    let size = imageSizeThatFits(in: geo.size)
                    let origin = CGPoint(
                        x: (geo.size.width - size.width) / 2,
                        y: (geo.size.height - size.height) / 2
                    )

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width, height: size.height)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)

                        // Dimming overlay outside crop
                        cropOverlay(imageOrigin: origin, imageSize: size, containerSize: geo.size)

                        // Crop rectangle border
                        Rectangle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)

                        // Grid lines
                        gridLines

                        // Drag handles
                        cropHandles
                    }
                    .onAppear {
                        imageFrame = CGRect(origin: origin, size: size)
                        let inset: CGFloat = 20
                        cropRect = CGRect(
                            x: origin.x + inset,
                            y: origin.y + inset,
                            width: size.width - inset * 2,
                            height: size.height - inset * 2
                        )
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDrag(value: value)
                            }
                            .onEnded { _ in
                                activeHandle = .none
                                isDragging = false
                            }
                    )
                }
            }
            .navigationTitle("Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        performCrop()
                        dismiss()
                    }
                    .foregroundStyle(Color.appPrimary)
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func imageSizeThatFits(in container: CGSize) -> CGSize {
        let aspectRatio = image.size.width / image.size.height
        var width = container.width
        var height = width / aspectRatio
        if height > container.height {
            height = container.height
            width = height * aspectRatio
        }
        return CGSize(width: width, height: height)
    }

    @ViewBuilder
    private func cropOverlay(imageOrigin: CGPoint, imageSize: CGSize, containerSize: CGSize) -> some View {
        // Semi-transparent overlay outside crop region
        Canvas { context, size in
            var path = Path()
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRect(cropRect)

            context.fill(path, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var gridLines: some View {
        // Rule of thirds
        let thirdW = cropRect.width / 3
        let thirdH = cropRect.height / 3
        ForEach(1..<3, id: \.self) { i in
            // Vertical
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 0.5, height: cropRect.height)
                .position(x: cropRect.minX + thirdW * CGFloat(i), y: cropRect.midY)
            // Horizontal
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: cropRect.width, height: 0.5)
                .position(x: cropRect.midX, y: cropRect.minY + thirdH * CGFloat(i))
        }
    }

    @ViewBuilder
    private var cropHandles: some View {
        let handles: [(CropHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: cropRect.minX, y: cropRect.minY)),
            (.topRight, CGPoint(x: cropRect.maxX, y: cropRect.minY)),
            (.bottomLeft, CGPoint(x: cropRect.minX, y: cropRect.maxY)),
            (.bottomRight, CGPoint(x: cropRect.maxX, y: cropRect.maxY))
        ]

        ForEach(handles, id: \.0) { handle, position in
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.3), radius: 2)
                .position(position)
        }
    }

    private func handleDrag(value: DragGesture.Value) {
        if !isDragging {
            isDragging = true
            dragStart = value.startLocation
            activeHandle = closestHandle(to: value.startLocation)
        }

        let translation = CGSize(
            width: value.location.x - dragStart.x,
            height: value.location.y - dragStart.y
        )
        dragStart = value.location

        let minSize: CGFloat = 50
        var newRect = cropRect

        switch activeHandle {
        case .topLeft:
            newRect.origin.x += translation.width
            newRect.origin.y += translation.height
            newRect.size.width -= translation.width
            newRect.size.height -= translation.height
        case .topRight:
            newRect.size.width += translation.width
            newRect.origin.y += translation.height
            newRect.size.height -= translation.height
        case .bottomLeft:
            newRect.origin.x += translation.width
            newRect.size.width -= translation.width
            newRect.size.height += translation.height
        case .bottomRight:
            newRect.size.width += translation.width
            newRect.size.height += translation.height
        case .none:
            newRect.origin.x += translation.width
            newRect.origin.y += translation.height
        }

        // Enforce minimum size
        if newRect.width >= minSize && newRect.height >= minSize {
            // Clamp to image bounds
            newRect.origin.x = max(imageFrame.minX, newRect.origin.x)
            newRect.origin.y = max(imageFrame.minY, newRect.origin.y)
            if newRect.maxX > imageFrame.maxX {
                newRect.size.width = imageFrame.maxX - newRect.origin.x
            }
            if newRect.maxY > imageFrame.maxY {
                newRect.size.height = imageFrame.maxY - newRect.origin.y
            }
            cropRect = newRect
        }
    }

    private func closestHandle(to point: CGPoint) -> CropHandle {
        let threshold: CGFloat = 40
        let handles: [(CropHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: cropRect.minX, y: cropRect.minY)),
            (.topRight, CGPoint(x: cropRect.maxX, y: cropRect.minY)),
            (.bottomLeft, CGPoint(x: cropRect.minX, y: cropRect.maxY)),
            (.bottomRight, CGPoint(x: cropRect.maxX, y: cropRect.maxY))
        ]

        for (handle, pos) in handles {
            if hypot(point.x - pos.x, point.y - pos.y) < threshold {
                return handle
            }
        }
        return .none
    }

    private func performCrop() {
        guard imageFrame.width > 0, imageFrame.height > 0 else { return }

        // Convert screen coordinates to image pixel coordinates
        let scaleX = image.size.width / imageFrame.width
        let scaleY = image.size.height / imageFrame.height

        let pixelRect = CGRect(
            x: (cropRect.minX - imageFrame.minX) * scaleX,
            y: (cropRect.minY - imageFrame.minY) * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )

        guard let cgImage = image.cgImage,
              let cropped = cgImage.cropping(to: pixelRect) else { return }

        let croppedImage = UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        onCrop(croppedImage)
    }
}

// Make CropHandle conform to Hashable for ForEach
extension CropView.CropHandle: Hashable {}
