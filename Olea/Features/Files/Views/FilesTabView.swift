import SwiftUI
import SwiftData
import TipKit

/// Wraps `.symbolEffect(.breathe...)` (iOS 18+) with a `.pulse` fallback for iOS 17.
private struct BreathingSymbol: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.symbolEffect(.breathe.plain.byLayer, options: .repeating)
        } else {
            content.symbolEffect(.pulse, options: .repeating)
        }
    }
}

struct FilesTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @Query(sort: \DocumentFile.importedAt, order: .reverse) private var allFiles: [DocumentFile]
    @State private var viewModel = FilesViewModel()
    @State private var actionsVM = FileActionsViewModel()

    @State private var selectedFile: DocumentFile?
    @State private var fileToRename: DocumentFile?
    @State private var fileToShowInfo: DocumentFile?
    @State private var fileToDelete: DocumentFile?
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isInitialLoad = true
    @State private var isSelecting = false
    @State private var selectedFiles: Set<UUID> = []
    @State private var showBatchDeleteConfirmation = false
    @State private var showFolderManagement = false
    @State private var fileToMoveToFolder: DocumentFile?
    @State private var fileToSetExpiry: DocumentFile?
    @State private var showExpiryDashboard = false
    @State private var fileToExtractData: DocumentFile?
    @State private var fileToDetectContacts: DocumentFile?
    @State private var showDocumentMap = false
    @State private var showImageGallery = false
    @State private var showSmartCategorize = false
    /// Pending feature waiting for either a free-pass or a rewarded-ad watch.
    /// When non-nil, the rewarded-ad gate sheet is presented for this feature
    /// and runs `open()` on successful unlock.
    @State private var gatedFeature: GatedFeature?

    /// Tiny value type that ferries everything the gate sheet needs to (a)
    /// render the right tool name/icon and (b) actually open the feature
    /// when the user finishes the ad. Identifiable so `.sheet(item:)` works.
    struct GatedFeature: Identifiable {
        let id: String        // FeatureGate counter key, e.g. "files.imageGallery"
        let label: String     // Human-readable name for the sheet
        let icon: String      // SF Symbol shown in the sheet medallion
        let open: () -> Void  // Side-effect to run after the user unlocks
    }

    /// Single entry-point for any premium Files-tab feature. Checks the
    /// FeatureGate; first tap opens free, subsequent taps present the
    /// rewarded-ad gate before opening.
    private func attemptOpen(featureID: String, label: String, icon: String, _ open: @escaping () -> Void) {
        HapticManager.light()
        switch FeatureGate.shared.evaluate(toolID: featureID) {
        case .openFree:
            FeatureGate.shared.recordUse(toolID: featureID)
            open()
        case .needsRewardedAd:
            gatedFeature = GatedFeature(id: featureID, label: label, icon: icon, open: open)
        }
    }

    /// Premium empty state: glass disk + iridescent AI shimmer rim + breathing
    /// file glyph. Used when the library has zero files (not when a search
    /// returns no matches — that has its own search empty state).
    private var emptyLibraryHero: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.appPrimary.opacity(0.22), .clear],
                                          center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 180, height: 180)
                    .blur(radius: 14)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 104, height: 104)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6))

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.appPrimary, Color.appAccent],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .modifier(BreathingSymbol())
            }
            .aiShimmerRim(cornerRadius: 60, lineWidth: 1.2)

            Text("No Files Yet")
                .font(.appH3)
                .foregroundStyle(Color.appText)
                .padding(.top, AppSpacing.xs)

            Text("Import documents to get started. Tap the + button to browse your files.")
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    // Insights dashboard (contextual, shown when not searching)
                    if viewModel.searchText.isEmpty && !allFiles.isEmpty {
                        InsightsDashboardView(files: allFiles)
                            .padding(.bottom, AppSpacing.sm)
                    }

                    TipView(ScanCompleteTip())
                        .tipBackground(Color.appBGCard)
                        .tint(Color.appPrimary)
                        .padding(.horizontal, AppSpacing.md)

                    // Search bar
                    AppSearchBar(text: $viewModel.searchText, placeholder: "Search files...")
                        .padding(.horizontal, AppSpacing.md)

                    // Unified filter bar: categories + tags
                    VStack(spacing: AppSpacing.xs) {
                        FileCategoryGridView(
                            files: allFiles,
                            selectedCategory: $viewModel.selectedCategory,
                            viewModel: viewModel
                        )
                        .padding(.horizontal, AppSpacing.md)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                // "All" chip — spring-driven selection.
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                        viewModel.selectedTag = nil
                                    }
                                    HapticManager.selection()
                                } label: {
                                    Text("All")
                                        .font(.appMicro.bold())
                                        .foregroundStyle(viewModel.selectedTag == nil ? .white : Color.appTextMuted)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 5)
                                        .background(
                                            viewModel.selectedTag == nil
                                                ? AnyShapeStyle(LinearGradient(
                                                    colors: [Color.appPrimary, Color.appAccent],
                                                    startPoint: .leading, endPoint: .trailing))
                                                : AnyShapeStyle(Color.appBGCard),
                                            in: Capsule()
                                        )
                                        .scaleEffect(viewModel.selectedTag == nil ? 1.06 : 1.0)
                                }
                                .buttonStyle(.plain)

                                ForEach(FileTag.allCases) { tag in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                            viewModel.selectedTag = viewModel.selectedTag == tag ? nil : tag
                                        }
                                        HapticManager.selection()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Circle().fill(tag.color).frame(width: 8, height: 8)
                                            Text(tag.localizedName)
                                                .font(.appMicro)
                                        }
                                        .foregroundStyle(viewModel.selectedTag == tag ? .white : Color.appTextMuted)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(viewModel.selectedTag == tag ? tag.color.opacity(0.85) : Color.appBGCard, in: Capsule())
                                        .scaleEffect(viewModel.selectedTag == tag ? 1.06 : 1.0)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }

                    // Sort header
                    HStack {
                        Text("\(filteredFiles.count) files")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextMuted)
                        Spacer()
                        SortMenuButton(selectedSort: $viewModel.sortOption)
                    }
                    .padding(.horizontal, AppSpacing.md)

                    if isInitialLoad {
                        SkeletonList(count: 5)
                    } else if filteredFiles.isEmpty && !viewModel.searchText.isEmpty {
                        // Search empty state
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "No Results",
                            message: "No files match \"\(viewModel.searchText)\". Try a different search term."
                        )
                        .frame(maxHeight: .infinity)
                    } else if filteredFiles.isEmpty {
                        // Library empty state — premium hero with mesh halo + breathing icon
                        emptyLibraryHero
                            .padding(.top, AppSpacing.xl)
                    } else {
                        // File list
                        FileListView(
                            files: filteredFiles,
                            onSelect: { file in
                                file.lastOpenedAt = Date()
                                try? modelContext.save()
                                selectedFile = file
                            },
                            onAction: { file, action in
                                handleAction(action, for: file)
                            },
                            isSelecting: isSelecting,
                            selectedFiles: $selectedFiles
                        )
                        .padding(.horizontal, AppSpacing.md)
                    }
                }
                .padding(.vertical, AppSpacing.sm)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Banner above the tab bar. Collapses to zero height when ads
                // are disabled (Pro user, consent denied), so no layout shift.
                AdBannerView()
            }
            .refreshable {
                HapticManager.light()
                // Force SwiftData to re-fetch by touching the view model
                viewModel.selectedCategory = viewModel.selectedCategory
            }
            .background {
                ZStack {
                    Color.appBGDark.ignoresSafeArea()
                    AnimatedMeshBackground()
                        .opacity(0.14)
                        .frame(height: 360)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeOut(duration: 0.3)) { isInitialLoad = false }
            }
            .onAppear {
                WidgetDataService.shared.syncAllWidgetData(allFiles: allFiles)
            }
            .onChange(of: allFiles.count) {
                WidgetDataService.shared.syncAllWidgetData(allFiles: allFiles)
            }
            .dropDestination(for: URL.self) { urls, _ in
                let importService = FileImportService()
                var firstError: Error?
                for url in urls {
                    do {
                        _ = try importService.importFiles(from: [url], into: modelContext)
                    } catch {
                        firstError = error
                    }
                }
                if let firstError {
                    errorMessage = firstError.localizedDescription
                    showError = true
                }
                HapticManager.medium()
                return !urls.isEmpty
            }
            .navigationTitle("Files (\(filteredFiles.count))")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting {
                        Button("Done") {
                            withAnimation { isSelecting = false; selectedFiles.removeAll() }
                        }
                        .foregroundStyle(Color.appPrimary)
                    } else {
                        HStack(spacing: AppSpacing.sm) {
                            Menu {
                                Button {
                                    attemptOpen(
                                        featureID: "files.imageGallery",
                                        label: "Image Gallery",
                                        icon: "photo.on.rectangle.angled"
                                    ) { showImageGallery = true }
                                } label: {
                                    Label("Image Gallery", systemImage: "photo.on.rectangle.angled")
                                }
                                Button {
                                    attemptOpen(
                                        featureID: "files.documentMap",
                                        label: "Document Map",
                                        icon: "map"
                                    ) { showDocumentMap = true }
                                } label: {
                                    Label("Document Map", systemImage: "map")
                                }
                                Button {
                                    attemptOpen(
                                        featureID: "files.expiryDashboard",
                                        label: "Expiry Dashboard",
                                        icon: "calendar.badge.clock"
                                    ) { showExpiryDashboard = true }
                                } label: {
                                    Label("Expiry Dashboard", systemImage: "calendar.badge.clock")
                                }
                                Button {
                                    attemptOpen(
                                        featureID: "files.smartCategorize",
                                        label: "Smart Categorize",
                                        icon: "sparkles"
                                    ) { showSmartCategorize = true }
                                } label: {
                                    Label("Smart Categorize", systemImage: "sparkles")
                                }
                                // Manage Folders is structural (not a premium
                                // feature) — keep it free, always.
                                Button {
                                    HapticManager.light()
                                    showFolderManagement = true
                                } label: {
                                    Label("Manage Folders", systemImage: "folder")
                                }
                                Divider()
                                Button {
                                    withAnimation { isSelecting = true }
                                } label: {
                                    Label("Select Files", systemImage: "checkmark.circle")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.appPrimary)
                            }
                            FileImportButton()
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedFile) { file in
                DocumentViewerRouter(file: file)
            }
            .onReceive(NotificationCenter.default.publisher(for: .oleaOpenDocumentFromSpotlight)) { note in
                openFileFromSpotlight(note: note)
            }
            .onChange(of: router.pendingFileIDToOpen) { _, newID in
                guard let newID else { return }
                openFile(byID: newID)
                router.pendingFileIDToOpen = nil
            }
            .sheet(item: $fileToRename) { file in
                FileRenameSheet(file: file) { newName in
                    do {
                        try actionsVM.rename(file, to: newName, context: modelContext)
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
            .sheet(item: $fileToShowInfo) { file in
                FileDetailSheet(file: file)
            }
            .sheet(isPresented: $showFolderManagement) {
                FolderManagementView()
            }
            .sheet(item: $fileToMoveToFolder) { file in
                MoveToFolderSheet(file: file)
            }
            .sheet(item: $fileToExtractData) { file in
                StructuredDataView(file: file)
            }
            .sheet(item: $fileToDetectContacts) { file in
                DocumentContactsView(file: file)
            }
            .sheet(item: $fileToSetExpiry) { file in
                SetExpirySheet(file: file)
            }
            .sheet(isPresented: $showImageGallery) {
                ImageGalleryView()
            }
            .sheet(isPresented: $showDocumentMap) {
                DocumentMapView()
            }
            .sheet(isPresented: $showSmartCategorize) {
                SmartCategorizeView()
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showExpiryDashboard) {
                ExpiryDashboardView()
            }
            .alert("Delete File?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { fileToDelete = nil }
                Button("Delete", role: .destructive) {
                    guard let file = fileToDelete else { return }
                    do {
                        try actionsVM.delete(file, context: modelContext)
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                    fileToDelete = nil
                }
            } message: {
                Text("This will permanently remove \"\(fileToDelete?.fullFileName ?? "")\" from the app.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
            .alert("Delete \(selectedFiles.count) Files?", isPresented: $showBatchDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    batchDelete()
                }
            } message: {
                Text("This will permanently remove \(selectedFiles.count) files.")
            }
            // Rewarded-ad gate for premium Files-tab features. Same gate UX as
            // the Tools tab — first use of each feature is free, subsequent
            // uses watch a short ad. Pro users skip entirely.
            .sheet(item: $gatedFeature) { feature in
                RewardedAdGateSheet(
                    toolName: feature.label,
                    toolIcon: feature.icon,
                    onUnlock: {
                        FeatureGate.shared.recordUse(toolID: feature.id)
                        let open = feature.open
                        gatedFeature = nil
                        open()
                    },
                    onCancel: { gatedFeature = nil }
                )
            }

            // Batch action bar
            if isSelecting && !selectedFiles.isEmpty {
                batchActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            } // ZStack
        }
    }

    private var filteredFiles: [DocumentFile] {
        viewModel.filteredAndSorted(allFiles)
    }

    private var batchActionBar: some View {
        HStack(spacing: AppSpacing.lg) {
            Button {
                HapticManager.medium()
                batchShare()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                        .font(.appMicro)
                }
            }
            .foregroundStyle(Color.appPrimary)

            Button {
                HapticManager.medium()
                showBatchDeleteConfirmation = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "trash")
                    Text("Delete")
                        .font(.appMicro)
                }
            }
            .foregroundStyle(Color.appDanger)
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.xl)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .padding(.bottom, AppSpacing.md)
        .accessibilityLabel("\(selectedFiles.count) files selected")
    }

    private func batchShare() {
        let urls = filteredFiles
            .filter { selectedFiles.contains($0.id) }
            .compactMap { $0.fileURL }
        guard !urls.isEmpty else { return }
        if let first = urls.first {
            ShareService.shared.share(fileURL: first)
        }
        withAnimation { isSelecting = false; selectedFiles.removeAll() }
    }

    private func batchDelete() {
        let files = filteredFiles.filter { selectedFiles.contains($0.id) }
        for file in files {
            try? actionsVM.delete(file, context: modelContext)
        }
        withAnimation { isSelecting = false; selectedFiles.removeAll() }
    }

    private func handleAction(_ action: FileRowAction, for file: DocumentFile) {
        switch action {
        case .rename:
            fileToRename = file
        case .delete:
            fileToDelete = file
            showDeleteConfirmation = true
        case .share:
            actionsVM.share(file)
        case .info:
            fileToShowInfo = file
        case .toggleFavorite:
            do {
                try actionsVM.toggleFavorite(file, context: modelContext)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        case .setTag(let tag):
            file.tagName = tag?.rawValue
            try? modelContext.save()
        case .moveToFolder:
            fileToMoveToFolder = file
        case .setExpiry:
            fileToSetExpiry = file
        case .extractData:
            // AI-powered structured data extraction — gated like other AI features.
            attemptOpen(
                featureID: "files.extractData",
                label: "Extract Data",
                icon: "tablecells.badge.ellipsis"
            ) { fileToExtractData = file }
        case .moveToVault:
            // Vault is a privacy/safety operation, not a premium feature — keep free.
            withAnimation {
                file.isInVault = true
                try? modelContext.save()
            }
            // Drop from Spotlight — vault is the one surface that must never
            // leak into system search.
            SpotlightIndexingService.shared.remove(id: file.id)
            HapticManager.success()
        case .detectContacts:
            // AI contact intelligence — gated.
            attemptOpen(
                featureID: "files.detectContacts",
                label: "Detect Contacts",
                icon: "person.crop.rectangle.badge.plus"
            ) { fileToDetectContacts = file }
        }
    }

    // MARK: - Spotlight handoff

    /// Resolve a Spotlight notification (`userInfo["id"] = UUID`) and open
    /// the matching document. Silently no-ops if the UUID doesn't match any
    /// current doc (e.g. user deleted it between the Spotlight result being
    /// shown and the tap landing).
    private func openFileFromSpotlight(note: Notification) {
        guard let id = note.userInfo?["id"] as? UUID else { return }
        openFile(byID: id)
    }

    private func openFile(byID id: UUID) {
        guard let match = allFiles.first(where: { $0.id == id }) else { return }
        // Vault docs are excluded from indexing, but defend in depth — never
        // bypass the vault auth flow from a Spotlight tap.
        guard !match.isInVault else { return }
        selectedFile = match
    }
}
