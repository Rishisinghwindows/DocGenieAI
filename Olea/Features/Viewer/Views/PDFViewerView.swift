import SwiftUI
import PDFKit
import PencilKit

struct PDFViewerView: View {
    let url: URL
    let fileName: String

    @State private var currentPage = 0
    @State private var totalPages = 0
    @State private var showThumbnails = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var isAnnotating = false
    @State private var canvasView = PKCanvasView()
    @State private var selectedColor: Color = .red
    @State private var selectedTool: AnnotationTool = .pen
    @State private var showShareSheet = false
    @State private var showInfoPanel = false
    @State private var pdfDocument: PDFDocument?
    @State private var pdfViewMode: PDFViewMode = .normal
    @State private var showTextNoteInput = false
    @State private var textNoteContent = ""
    @State private var textNotes: [TextAnnotation] = []
    @State private var textNoteTapPosition: CGPoint = .zero
    @State private var selectedNote: TextAnnotation?
    @State private var showNoteDetail = false
    @State private var showNotesList = false

    enum PDFViewMode: String, CaseIterable {
        case normal = "Normal"
        case dark = "Dark"
        case sepia = "Sepia"

        var icon: String {
            switch self {
            case .normal: return "sun.max"
            case .dark: return "moon.fill"
            case .sepia: return "book"
            }
        }
    }

    enum AnnotationTool: String, CaseIterable {
        case pen, highlighter, eraser, textNote
        var icon: String {
            switch self {
            case .pen: return "pencil.tip"
            case .highlighter: return "highlighter"
            case .eraser: return "eraser"
            case .textNote: return "text.bubble"
            }
        }
    }

    private let annotationColors: [Color] = [.red, .blue, .green, .orange, .black]

    var body: some View {
        ZStack {
            // Main PDF view
            PDFKitView(url: url, currentPage: $currentPage, totalPages: $totalPages)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(!isAnnotating)
                .modifier(PDFViewModeModifier(mode: pdfViewMode))

            // Annotation canvas overlay
            if isAnnotating && selectedTool != .textNote {
                AnnotationCanvas(canvasView: $canvasView, selectedTool: selectedTool, selectedColor: selectedColor)
                    .ignoresSafeArea(edges: .bottom)
            }

            // Text note tap target overlay
            if isAnnotating && selectedTool == .textNote {
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            textNoteTapPosition = CGPoint(
                                x: location.x / geometry.size.width,
                                y: location.y / geometry.size.height
                            )
                            textNoteContent = ""
                            HapticManager.light()
                            showTextNoteInput = true
                        }
                }
                .ignoresSafeArea(edges: .bottom)
            }

            // Text note indicators overlay
            TextNoteOverlay(
                notes: textNotes,
                currentPage: currentPage,
                onTapNote: { note in
                    selectedNote = note
                    showNoteDetail = true
                },
                onDeleteNote: { note in
                    textNotes.removeAll { $0.id == note.id }
                    HapticManager.success()
                }
            )
            .allowsHitTesting(!isAnnotating || selectedTool != .textNote)

            // Notes floating button
            if !textNotes.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            HapticManager.light()
                            showNotesList = true
                        } label: {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 14))
                                Text("\(textNotes.count)")
                                    .font(.appCaption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(Color.appPrimary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                            )
                        }
                        .padding(.trailing, AppSpacing.md)
                        .padding(.top, AppSpacing.xl)
                    }
                    Spacer()
                }
            }

            // Bottom controls
            VStack {
                Spacer()

                if isAnnotating {
                    annotationToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    bottomBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(Color.appBGDark)
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // View Mode
                Menu {
                    ForEach(PDFViewMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation { pdfViewMode = mode }
                        } label: {
                            Label(mode.rawValue, systemImage: mode.icon)
                        }
                    }
                } label: {
                    Image(systemName: pdfViewMode.icon)
                        .foregroundStyle(pdfViewMode == .normal ? Color.appTextMuted : Color.appPrimary)
                }

                // Search
                Button {
                    withAnimation { showSearch.toggle() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.appTextMuted)
                }

                // Thumbnails
                Button {
                    withAnimation { showThumbnails.toggle() }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .foregroundStyle(Color.appTextMuted)
                }

                // Annotate
                Button {
                    withAnimation { isAnnotating.toggle() }
                } label: {
                    Image(systemName: isAnnotating ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                        .foregroundStyle(isAnnotating ? Color.appPrimary : Color.appTextMuted)
                }

                // Share
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.appTextMuted)
                }
            }
        }
        .sheet(isPresented: $showThumbnails) {
            PDFThumbnailGridView(url: url, currentPage: currentPage) { page in
                currentPage = page
                showThumbnails = false
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(24)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = url as URL? {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showInfoPanel) {
            PDFInfoPanel(url: url, fileName: fileName, pageCount: totalPages)
                .presentationDetents([.medium])
                .presentationCornerRadius(24)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showTextNoteInput) {
            TextNoteInputSheet(
                text: $textNoteContent,
                selectedColor: selectedColor,
                onSave: {
                    let annotation = TextAnnotation(
                        text: textNoteContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        page: currentPage,
                        position: textNoteTapPosition,
                        color: selectedColor
                    )
                    textNotes.append(annotation)
                    textNoteContent = ""
                    showTextNoteInput = false
                    HapticManager.success()
                },
                onCancel: {
                    textNoteContent = ""
                    showTextNoteInput = false
                }
            )
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showNoteDetail) {
            if let note = selectedNote {
                TextNoteDetailView(note: note) {
                    textNotes.removeAll { $0.id == note.id }
                    selectedNote = nil
                    showNoteDetail = false
                    HapticManager.success()
                }
                .presentationDetents([.height(200)])
                .presentationCornerRadius(24)
                .presentationBackground(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showNotesList) {
            TextNotesListView(
                notes: textNotes,
                currentPage: currentPage,
                onDelete: { note in
                    textNotes.removeAll { $0.id == note.id }
                    HapticManager.success()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(24)
            .presentationBackground(.ultraThinMaterial)
        }
        .overlay {
            if showSearch {
                searchBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            pdfDocument = PDFDocument(url: url)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: AppSpacing.lg) {
            // Page indicator
            Button {
                showInfoPanel = true
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                    Text("\(currentPage) / \(totalPages)")
                        .font(.appMono)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color.appText)
            }

            Spacer()

            // Page navigation
            HStack(spacing: AppSpacing.md) {
                Button {
                    if currentPage > 1 { currentPage -= 1 }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(currentPage > 1 ? Color.appText : Color.appTextDim)
                }
                .disabled(currentPage <= 1)

                Button {
                    if currentPage < totalPages { currentPage += 1 }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(currentPage < totalPages ? Color.appText : Color.appTextDim)
                }
                .disabled(currentPage >= totalPages)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 2)
        )
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.sm)
    }

    // MARK: - Annotation Toolbar

    private var annotationToolbar: some View {
        VStack(spacing: AppSpacing.sm) {
            // Tools
            HStack(spacing: AppSpacing.md) {
                ForEach(AnnotationTool.allCases, id: \.self) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        Image(systemName: tool.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(selectedTool == tool ? Color.appPrimary : Color.appTextMuted)
                            .frame(width: 40, height: 40)
                            .background(selectedTool == tool ? Color.appPrimary.opacity(0.15) : .clear, in: Circle())
                    }
                }

                Divider().frame(height: 28)

                // Colors
                ForEach(annotationColors, id: \.self) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: selectedColor == color ? 26 : 20)
                            .overlay(selectedColor == color ? Circle().stroke(.white, lineWidth: 2) : nil)
                    }
                }

                Spacer()

                // Clear + Done
                Button {
                    canvasView.drawing = PKDrawing()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.appDanger)
                }

                Button("Done") {
                    withAnimation { isAnnotating = false }
                }
                .font(.appBody)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appPrimary)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 2)
        )
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.appTextDim)

                TextField("Search in document...", text: $searchText)
                    .font(.appBody)
                    .foregroundStyle(Color.appText)
                    .onSubmit {
                        searchInPDF()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.appTextDim)
                    }
                }

                Button("Done") {
                    withAnimation { showSearch = false }
                }
                .font(.appCaption)
                .foregroundStyle(Color.appPrimary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 8)
            )
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)

            Spacer()
        }
    }

    private func searchInPDF() {
        // PDFKit search is handled natively through the PDFView
        // This triggers highlight — actual implementation would need PDFView reference
    }
}

// MARK: - Annotation Canvas

struct AnnotationCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var selectedTool: PDFViewerView.AnnotationTool
    var selectedColor: Color

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        updateTool()
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        updateTool()
    }

    private func updateTool() {
        let uiColor = UIColor(selectedColor)
        switch selectedTool {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: 3)
        case .highlighter:
            canvasView.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.3), width: 20)
        case .eraser:
            canvasView.tool = PKEraserTool(.bitmap)
        case .textNote:
            break // Handled by TextNoteOverlay, not PencilKit
        }
    }
}

// MARK: - PDF Thumbnail Grid

struct PDFThumbnailGridView: View {
    let url: URL
    let currentPage: Int
    let onSelectPage: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    private var document: PDFDocument? { PDFDocument(url: url) }
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let doc = document {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<doc.pageCount, id: \.self) { index in
                            Button {
                                onSelectPage(index + 1)
                            } label: {
                                VStack(spacing: 4) {
                                    PDFPageThumbnail(document: doc, pageIndex: index)
                                        .frame(height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    index + 1 == currentPage ? Color.appPrimary : Color.appBorder,
                                                    lineWidth: index + 1 == currentPage ? 2 : 1
                                                )
                                        )
                                        .shadow(color: index + 1 == currentPage ? Color.appPrimary.opacity(0.3) : .clear, radius: 6)

                                    Text("\(index + 1)")
                                        .font(.appMicro)
                                        .fontWeight(index + 1 == currentPage ? .bold : .regular)
                                        .foregroundStyle(index + 1 == currentPage ? Color.appPrimary : Color.appTextDim)
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                }
            }
            .background(Color.appBGDark)
            .navigationTitle("Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }
}

// MARK: - PDF Page Thumbnail

struct PDFPageThumbnail: View {
    let document: PDFDocument
    let pageIndex: Int
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.appBGCard)
                    .overlay(
                        ProgressView()
                            .tint(Color.appTextDim)
                    )
            }
        }
        .task {
            thumbnail = await generateThumbnail()
        }
    }

    private func generateThumbnail() async -> UIImage? {
        guard let page = document.page(at: pageIndex) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 200 / bounds.width
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.translateBy(x: 0, y: bounds.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}

// MARK: - PDF Info Panel

struct PDFInfoPanel: View {
    let url: URL
    let fileName: String
    let pageCount: Int
    @Environment(\.dismiss) private var dismiss

    private var fileSize: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "Unknown" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return "\(size / 1024) KB" }
        return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("File") {
                    infoRow("Name", value: fileName)
                    infoRow("Size", value: fileSize)
                    infoRow("Pages", value: "\(pageCount)")
                    infoRow("Type", value: "PDF Document")
                }

                if let doc = PDFDocument(url: url) {
                    Section("Metadata") {
                        if let attrs = doc.documentAttributes {
                            if let title = attrs[PDFDocumentAttribute.titleAttribute] as? String, !title.isEmpty {
                                infoRow("Title", value: title)
                            }
                            if let author = attrs[PDFDocumentAttribute.authorAttribute] as? String, !author.isEmpty {
                                infoRow("Author", value: author)
                            }
                            if let subject = attrs[PDFDocumentAttribute.subjectAttribute] as? String, !subject.isEmpty {
                                infoRow("Subject", value: subject)
                            }
                            if let creator = attrs[PDFDocumentAttribute.creatorAttribute] as? String, !creator.isEmpty {
                                infoRow("Creator", value: creator)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBGDark)
            .navigationTitle("Document Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
            Spacer()
            Text(value)
                .font(.appBody)
                .foregroundStyle(Color.appText)
                .lineLimit(1)
        }
        .listRowBackground(Color.appBGCard)
    }
}

// MARK: - PDF View Mode Modifier

struct PDFViewModeModifier: ViewModifier {
    let mode: PDFViewerView.PDFViewMode

    func body(content: Content) -> some View {
        switch mode {
        case .normal:
            content
        case .dark:
            content
                .colorInvert()
                .colorMultiply(Color(red: 0.9, green: 0.9, blue: 0.85))
        case .sepia:
            content
                .overlay(
                    Color(red: 0.96, green: 0.93, blue: 0.85)
                        .blendMode(.multiply)
                        .allowsHitTesting(false)
                )
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
