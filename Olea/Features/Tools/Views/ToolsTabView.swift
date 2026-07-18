import SwiftUI
import TipKit

struct ToolsTabView: View {
    @State private var activeTool: ToolItem?
    @State private var showScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var showReview = false
    @State private var searchText = ""
    /// When set, the rewarded-ad gate sheet is shown for this tool. On
    /// successful reward, we record the use and open `activeTool` (or scanner).
    @State private var gatedTool: ToolItem?
    private let tryAIToolsTip = TryAIToolsTip()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 2)

    @State private var showAdvanced = false

    private var filteredTools: [ToolItem] {
        let pool = showAdvanced || !searchText.isEmpty
            ? ToolItem.allCases
            : ToolItem.allCases.filter { !$0.isAdvanced }
        if searchText.isEmpty { return pool }
        return pool.filter {
            // Match against both the English canonical name (so users who
            // think in English can still search e.g. "merge") AND the
            // localized name (so users see results in their own language).
            $0.rawValue.localizedCaseInsensitiveContains(searchText) ||
            $0.localizedName.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedTools: [(String, [ToolItem])] {
        // Group by the stable English `sectionID` — `section` is localized
        // and was breaking equality compares against the literal keys here.
        // The display side reads `tool.section` (already localized).
        let sections = ["Scan", "AI Intelligence", "Edit", "Enhance", "Convert", "Protect", "Compare", "Share & Create"]
        return sections.compactMap { sectionID in
            let tools = filteredTools.filter { $0.sectionID == sectionID }
            return tools.isEmpty ? nil : (sectionID, tools)
        }
    }

    private var hiddenAdvancedCount: Int {
        ToolItem.allCases.filter { $0.isAdvanced }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background sits BEHIND the ScrollView as a sibling (not as a
                // .background modifier) so the TimelineView in MeshGradient
                // doesn't continuously invalidate the ScrollView's hit-test
                // tree. On iOS 26 the .background placement starved the
                // scroll gesture recognizer and the screen became unscrollable.
                Color.appBGDark.ignoresSafeArea()
                AnimatedMeshBackground()
                    .opacity(0.16)
                    .frame(height: 380)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

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
                                sectionHeader(section)

                                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                                    ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                                        ToolCardView(tool: tool) {
                                            handleToolTap(tool)
                                        }
                                        .scrollTransition(.interactive.threshold(.visible(0.3))) { content, phase in
                                            content
                                                .opacity(1 - abs(phase.value) * 0.25)
                                                .scaleEffect(1 - abs(phase.value) * 0.03)
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                        }

                        // Advanced-tools disclosure. Subtractive UX: don't bury power
                        // features, just gate them behind one tap.
                        if searchText.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() }
                                HapticManager.light()
                            } label: {
                                HStack {
                                    Image(systemName: showAdvanced ? "chevron.up.circle" : "chevron.down.circle")
                                    // Branch the ternary so each Text gets a
                                    // LocalizedStringKey — the unified form
                                    // collapses to plain String and bypasses
                                    // the catalog lookup.
                                    Group {
                                        if showAdvanced {
                                            Text("Hide advanced tools")
                                        } else {
                                            Text("Show \(hiddenAdvancedCount) advanced tools")
                                        }
                                    }
                                    .font(.appCaption.bold())
                                    Spacer()
                                }
                                .foregroundStyle(Color.appPrimary)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(Color.appBGCard.opacity(0.5), in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.top, AppSpacing.md)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // Banner above the tab bar. Collapses to zero height when
                    // ads are disabled (Pro user, consent denied) so no
                    // reserved space and no layout shift.
                    AdBannerView()
                }
            }
            .navigationTitle("Tools")
            // Deep-link entry: OleaApp posts .oleaOpenScanner when the
            // docsage://scan URL fires (typically from the "Scan with Olea"
            // Siri Shortcut). AppTabView has already switched to this tab
            // by the time this arrives.
            .onReceive(NotificationCenter.default.publisher(for: .oleaOpenScanner)) { _ in
                showScanner = true
            }
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
            .sheet(item: $gatedTool) { tool in
                RewardedAdGateSheet(
                    toolName: tool.localizedName,
                    toolIcon: tool.systemImage,
                    onUnlock: { unlockGatedTool(tool) },
                    onCancel: { gatedTool = nil }
                )
            }
        }
    }

    /// Called by the gate sheet after a successful rewarded ad (or fall-open).
    /// Records the use so future taps count correctly, then opens the tool.
    private func unlockGatedTool(_ tool: ToolItem) {
        FeatureGate.shared.recordUse(toolID: tool.id)
        gatedTool = nil
        if tool == .scanner {
            showScanner = true
        } else {
            activeTool = tool
        }
    }

    /// Section title with a small animated sparkle on the AI section so it
    /// reads as the differentiator vs. utility tool groups.
    @ViewBuilder
    private func sectionHeader(_ section: String) -> some View {
        HStack(spacing: 6) {
            if section == "AI Intelligence" {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appPrimary, Color.appAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            // `section` is the English sectionID; wrap so the catalog
            // resolves it to the user's language at render time.
            Text(LocalizedStringKey(section))
                .font(.appCaption.bold())
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(section == "AI Intelligence" ? Color.appPrimary : Color.appTextMuted)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .accessibilityAddTraits(.isHeader)
    }

    private func handleToolTap(_ tool: ToolItem) {
        HapticManager.medium()
        switch FeatureGate.shared.evaluate(toolID: tool.id) {
        case .openFree:
            FeatureGate.shared.recordUse(toolID: tool.id)
            if tool == .scanner {
                showScanner = true
            } else {
                activeTool = tool
            }
        case .needsRewardedAd:
            // Present the gate sheet — it'll call back into unlockGatedTool
            // after the user watches the ad (or after fall-open).
            gatedTool = tool
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
        case .redactPDF: RedactPDFView()
        case .summarizePDF: SummarizePDFView()
        case .askPDF: AskPDFView()
        case .translatePDF: TranslatePDFView()
        case .handwriting: HandwritingView()
        case .formAutofill: FormAutofillView()
        case .templates: TemplatesView()
        case .emailPDF: EmailPDFView()
        case .qrShare: QRShareView()
        case .scanner: EmptyView()
        }
    }
}
