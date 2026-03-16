import SwiftUI
import SwiftData
import TipKit

struct FilesTabView: View {
    @Environment(\.modelContext) private var modelContext
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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    TipView(ScanCompleteTip())
                        .tipBackground(Color.appBGCard)
                        .tint(Color.appPrimary)
                        .padding(.horizontal, AppSpacing.md)

                    // Search bar
                    AppSearchBar(text: $viewModel.searchText, placeholder: "Search files...")
                        .padding(.horizontal, AppSpacing.md)

                    // Search scope toggle (visible when searching)
                    if !viewModel.searchText.isEmpty {
                        Picker("Search in", selection: $viewModel.searchScope) {
                            ForEach(FilesViewModel.SearchScope.allCases, id: \.self) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // Category filter
                    FileCategoryGridView(
                        files: allFiles,
                        selectedCategory: $viewModel.selectedCategory,
                        viewModel: viewModel
                    )
                    .padding(.horizontal, AppSpacing.md)

                    // Tag filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            // "All" chip
                            Button {
                                viewModel.selectedTag = nil
                            } label: {
                                Text("All")
                                    .font(.appMicro)
                                    .foregroundStyle(viewModel.selectedTag == nil ? .white : Color.appTextMuted)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(viewModel.selectedTag == nil ? Color.appPrimary : Color.appBGCard, in: Capsule())
                            }

                            ForEach(FileTag.allCases) { tag in
                                Button {
                                    viewModel.selectedTag = viewModel.selectedTag == tag ? nil : tag
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle().fill(tag.color).frame(width: 8, height: 8)
                                        Text(tag.rawValue)
                                            .font(.appMicro)
                                    }
                                    .foregroundStyle(viewModel.selectedTag == tag ? .white : Color.appTextMuted)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(viewModel.selectedTag == tag ? tag.color.opacity(0.8) : Color.appBGCard, in: Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
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
            .refreshable {
                HapticManager.light()
                // Force SwiftData to re-fetch by touching the view model
                viewModel.selectedCategory = viewModel.selectedCategory
            }
            .background(Color.appBGDark)
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
                for url in urls {
                    let importService = FileImportService()
                    _ = try? importService.importFiles(from: [url], into: modelContext)
                }
                HapticManager.medium()
                return !urls.isEmpty
            }
            .navigationTitle("Files")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting {
                        Button("Done") {
                            withAnimation { isSelecting = false; selectedFiles.removeAll() }
                        }
                        .foregroundStyle(Color.appPrimary)
                    } else {
                        HStack(spacing: AppSpacing.md) {
                            Button {
                                HapticManager.light()
                                showExpiryDashboard = true
                            } label: {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(Color.appPrimary)
                            }
                            Button {
                                HapticManager.light()
                                showFolderManagement = true
                            } label: {
                                Image(systemName: "folder")
                                    .foregroundStyle(Color.appPrimary)
                            }
                            Button {
                                withAnimation { isSelecting = true }
                            } label: {
                                Image(systemName: "checkmark.circle")
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
            .sheet(item: $fileToSetExpiry) { file in
                SetExpirySheet(file: file)
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
            fileToExtractData = file
        case .moveToVault:
            withAnimation {
                file.isInVault = true
                try? modelContext.save()
            }
            HapticManager.success()
        }
    }
}
