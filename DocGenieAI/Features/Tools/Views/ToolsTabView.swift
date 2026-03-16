import SwiftUI
import TipKit

struct ToolsTabView: View {
    @State private var activeTool: ToolItem?
    @State private var showScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var showReview = false
    @State private var searchText = ""
    private let tryAIToolsTip = TryAIToolsTip()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 2)

    private var filteredTools: [ToolItem] {
        if searchText.isEmpty { return ToolItem.allCases }
        return ToolItem.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedTools: [(String, [ToolItem])] {
        let sections = ["Scanner", "PDF Tools", "AI Tools", "Converters", "Utilities"]
        return sections.compactMap { section in
            let tools = filteredTools.filter { $0.section == section }
            return tools.isEmpty ? nil : (section, tools)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    TipView(tryAIToolsTip)
                        .tipBackground(Color.appBGCard)
                        .tint(Color.appPrimary)
                        .padding(.horizontal, AppSpacing.md)

                    AppSearchBar(text: $searchText, placeholder: "Search tools...")
                        .padding(.horizontal, AppSpacing.md)

                    ForEach(groupedTools, id: \.0) { section, tools in
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(section)
                                .font(.appH3)
                                .foregroundStyle(Color.appTextMuted)
                                .padding(.horizontal, AppSpacing.md)
                                .accessibilityAddTraits(.isHeader)

                            LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                                ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                                    ToolCardView(tool: tool) {
                                        handleToolTap(tool)
                                    }
                                    .scrollReveal()
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                }
                .padding(.vertical, AppSpacing.sm)
            }
            .background(Color.appBGDark)
            .navigationTitle("Tools")
            .fullScreenCover(isPresented: $showScanner) {
                DocumentCameraView(
                    onScanComplete: { images in
                        scannedImages = images
                        showScanner = false
                        if !images.isEmpty { showReview = true }
                    },
                    onCancel: { showScanner = false }
                )
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showReview) {
                ScanReviewView(scannedImages: scannedImages)
            }
            .task {
                await TryAIToolsTip.toolsTabVisited.donate()
            }
            .sheet(item: $activeTool) { tool in
                toolSheet(for: tool)
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    private func handleToolTap(_ tool: ToolItem) {
        HapticManager.medium()
        if tool == .scanner {
            showScanner = true
        } else {
            activeTool = tool
        }
    }

    @ViewBuilder
    private func toolSheet(for tool: ToolItem) -> some View {
        switch tool {
        case .mergePDF: MergePDFView()
        case .splitPDF: SplitPDFView()
        case .compressPDF: CompressPDFView()
        case .lockPDF: LockPDFView()
        case .unlockPDF: UnlockPDFView()
        case .extractPages: ExtractPagesPDFView()
        case .rotatePDF: RotatePDFView()
        case .reorderPDF: ReorderPDFView()
        case .pageNumbers: PageNumbersPDFView()
        case .watermark: WatermarkPDFView()
        case .batchProcess: BatchProcessView()
        case .ocrText: OCRTextView()
        case .comparePDF: ComparePDFView()
        case .imageToPDF: ImageToPDFView()
        case .docToPDF: DocToPDFView()
        case .pdfToImage: PDFToImageView()
        case .pdfToText: PDFToTextView()
        case .signPDF: SignPDFView()
        case .cropPDF: CropPDFView()
        case .metadataEditor: MetadataEditorView()
        case .summarizePDF: SummarizePDFView()
        case .askPDF: AskPDFView()
        case .translatePDF: TranslatePDFView()
        case .templates: TemplatesView()
        case .emailPDF: EmailPDFView()
        case .qrShare: QRShareView()
        case .scanner: EmptyView()
        }
    }
}
