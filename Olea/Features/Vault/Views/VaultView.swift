import SwiftUI
import SwiftData

struct VaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<DocumentFile> { $0.isInVault == true },
        sort: \DocumentFile.importedAt,
        order: .reverse
    ) private var vaultFiles: [DocumentFile]

    @State private var vaultService = VaultService.shared
    @State private var searchText = ""
    @State private var showFilePicker = false
    @State private var selectedFile: DocumentFile?
    @State private var fileToDelete: DocumentFile?
    @State private var showDeleteConfirmation = false
    @State private var showSuccessAnimation = false

    private var filteredFiles: [DocumentFile] {
        if searchText.isEmpty {
            return vaultFiles
        }
        let query = searchText.lowercased()
        return vaultFiles.filter {
            $0.name.lowercased().contains(query) || $0.fileExtension.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vaultService.isUnlocked {
                    unlockedView
                } else {
                    lockedView
                }
            }
            .background(Color.appBGDark)
            .navigationTitle("Secure Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
                if vaultService.isUnlocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: AppSpacing.md) {
                            Button {
                                HapticManager.light()
                                showFilePicker = true
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundStyle(Color.appPrimary)
                            }
                            Button {
                                HapticManager.light()
                                vaultService.lock()
                            } label: {
                                Image(systemName: "lock")
                                    .foregroundStyle(Color.appPrimary)
                            }
                        }
                    }
                }
            }
            .onDisappear {
                vaultService.lock()
            }
            .sheet(isPresented: $showFilePicker) {
                VaultFilePickerView { selectedFiles in
                    for file in selectedFiles {
                        file.isInVault = true
                        SpotlightIndexingService.shared.remove(id: file.id)
                    }
                    try? modelContext.save()
                    if !selectedFiles.isEmpty {
                        HapticManager.success()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showSuccessAnimation = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showSuccessAnimation = false
                        }
                    }
                }
                .presentationCornerRadius(24)
                .presentationBackground(.ultraThinMaterial)
            }
            .navigationDestination(item: $selectedFile) { file in
                DocumentViewerRouter(file: file)
            }
            .alert("Delete File?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { fileToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let file = fileToDelete {
                        if let url = file.fileURL {
                            try? FileManager.default.removeItem(at: url)
                        }
                        modelContext.delete(file)
                        try? modelContext.save()
                    }
                    fileToDelete = nil
                }
            } message: {
                Text("This will permanently remove \"\(fileToDelete?.fullFileName ?? "")\" from the app.")
            }
            .overlay {
                if showSuccessAnimation {
                    VStack(spacing: AppSpacing.md) {
                        AnimatedCheckmark()
                        Text("Added to Vault")
                            .font(.appH3)
                            .foregroundStyle(Color.appText)
                    }
                    .padding(AppSpacing.xl)
                    .glassCard()
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Locked State

    private var lockedView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .breathingGlow()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.appPrimary)
            }

            VStack(spacing: AppSpacing.sm) {
                Text("Secure Vault")
                    .font(.appH1)
                    .foregroundStyle(Color.appText)

                Text("Your sensitive documents are protected")
                    .font(.appBody)
                    .foregroundStyle(Color.appTextMuted)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(
                title: biometricButtonTitle,
                icon: biometricIcon
            ) {
                Task {
                    let success = await vaultService.authenticate()
                    if success {
                        HapticManager.success()
                    } else {
                        HapticManager.error()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.md)

            Spacer()
            Spacer()
        }
        .padding(AppSpacing.lg)
        .glassCard()
        .padding(AppSpacing.md)
    }

    // MARK: - Unlocked State

    private var unlockedView: some View {
        VStack(spacing: 0) {
            AppSearchBar(text: $searchText, placeholder: "Search vault files...")
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)

            if filteredFiles.isEmpty {
                EmptyStateView(
                    icon: "lock.shield",
                    title: "No Documents in Vault",
                    message: "Move sensitive documents here for protection. Tap + to add files.",
                    buttonTitle: "Add Files",
                    action: { showFilePicker = true }
                )
            } else {
                List {
                    ForEach(filteredFiles) { file in
                        Button {
                            file.lastOpenedAt = Date()
                            try? modelContext.save()
                            selectedFile = file
                        } label: {
                            vaultFileRow(file)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.appBGCard)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                fileToDelete = file
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                if let url = file.fileURL {
                                    ShareService.shared.share(fileURL: url)
                                }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(Color.appAccent)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                withAnimation {
                                    file.isInVault = false
                                    try? modelContext.save()
                                }
                                // Coming out of the vault — restore the doc to
                                // Spotlight so the user can find it again from
                                // system search.
                                SpotlightIndexingService.shared.index(file)
                                HapticManager.medium()
                            } label: {
                                Label("Remove from Vault", systemImage: "lock.open")
                            }
                            .tint(Color.appWarning)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - File Row

    private func vaultFileRow(_ file: DocumentFile) -> some View {
        HStack(spacing: AppSpacing.md) {
            FileTypeIcon(fileExtension: file.fileExtension)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(file.fullFileName)
                    .font(.appBody)
                    .foregroundStyle(Color.appText)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.sm) {
                    Text(file.fileSize.formattedFileSize)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextDim)

                    Text(file.importedAt.relativeDisplay)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextDim)
                }
            }

            Spacer()

            if file.expiryDate != nil {
                if file.isExpired {
                    Text("Expired")
                        .font(.appMicro)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appDanger, in: Capsule())
                } else if file.isExpiringSoon {
                    Text("Expiring")
                        .font(.appMicro)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appWarning, in: Capsule())
                }
            }
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Helpers

    private var biometricIcon: String {
        switch vaultService.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.open"
        }
    }

    private var biometricButtonTitle: String {
        switch vaultService.biometricType {
        case .faceID:
            return "Unlock with Face ID"
        case .touchID:
            return "Unlock with Touch ID"
        default:
            return "Unlock Vault"
        }
    }
}
