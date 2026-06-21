import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedCategory: TemplateCategory = .business
    @State private var isProcessing = false
    @State private var didComplete = false
    @State private var resultFileName: String?
    @State private var showError = false
    @State private var errorMessage: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 2)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    categoryPicker

                    templateGrid
                }
                .padding(.vertical, AppSpacing.sm)
            }
            .background(Color.appBGDark)
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isProcessing {
                        ProgressView()
                    } else if didComplete {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
            .confettiOnComplete(didComplete)
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(TemplateCategory.allCases) { category in
                    Button {
                        HapticManager.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: category.systemImage)
                                .font(.system(size: 14))
                            Text(category.rawValue)
                                .font(.appCaption)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            selectedCategory == category
                                ? AnyShapeStyle(Color.appPrimary.opacity(0.2))
                                : AnyShapeStyle(Color.appBGCard)
                        )
                        .foregroundStyle(
                            selectedCategory == category ? Color.appPrimary : Color.appTextMuted
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    selectedCategory == category ? Color.appPrimary.opacity(0.5) : Color.appBorder,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Template Grid

    private var templateGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(selectedCategory.rawValue)
                .font(.appH3)
                .foregroundStyle(Color.appTextMuted)
                .padding(.horizontal, AppSpacing.md)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                ForEach(Array(DocumentTemplate.templates(for: selectedCategory).enumerated()), id: \.element.id) { index, template in
                    templateCard(template)
                        .staggeredAppear(index: index)
                }
            }
            .padding(.horizontal, AppSpacing.md)

            if didComplete, let name = resultFileName {
                successBanner(name: name)
                    .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    // MARK: - Template Card

    private func templateCard(_ template: DocumentTemplate) -> some View {
        Button {
            generateTemplate(template)
        } label: {
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(template.category.color.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: template.systemImage)
                        .font(.system(size: 22))
                        .foregroundStyle(template.category.color)
                }
                .glow(color: template.category.color, radius: 8)

                Text(template.name)
                    .font(.appH3)
                    .foregroundStyle(Color.appText)

                Text(template.description)
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .glassCard()
        }
        .buttonStyle(.scale)
        .disabled(isProcessing)
        .accessibilityLabel("\(template.name), \(template.description)")
        .accessibilityHint("Double tap to create document from template")
    }

    // MARK: - Success Banner

    private func successBanner(name: String) -> some View {
        AppCard {
            VStack(spacing: AppSpacing.sm) {
                AnimatedCheckmark()
                Text("Saved as \(name)")
                    .font(.appBody)
                    .foregroundStyle(Color.appSuccess)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Generate Template

    private func generateTemplate(_ template: DocumentTemplate) {
        HapticManager.medium()
        isProcessing = true
        didComplete = false
        resultFileName = nil

        Task { @MainActor in
            defer { isProcessing = false }
            do {
                let pdfData = template.generatePDF()
                let fileName = template.defaultFileName()
                let destinationURL = FileStorageService.shared.appFilesDirectory
                    .appendingPathComponent("\(fileName).pdf")

                // Handle name collisions
                var finalURL = destinationURL
                var counter = 1
                while FileManager.default.fileExists(atPath: finalURL.path) {
                    finalURL = FileStorageService.shared.appFilesDirectory
                        .appendingPathComponent("\(fileName) (\(counter)).pdf")
                    counter += 1
                }

                try pdfData.write(to: finalURL)

                let relativePath = AppConstants.appDocumentsSubdirectory + "/" + finalURL.lastPathComponent
                let metadata = FileMetadataService.shared.extractMetadata(from: finalURL)

                let docFile = DocumentFile(
                    name: (finalURL.lastPathComponent as NSString).deletingPathExtension,
                    fileExtension: "pdf",
                    relativeFilePath: relativePath,
                    fileSize: metadata.fileSize,
                    pageCount: metadata.pageCount
                )
                modelContext.insert(docFile)
                try modelContext.save()

                resultFileName = docFile.fullFileName
                didComplete = true
                HapticManager.success()

                NotificationCenter.default.post(
                    name: .toolDidProduceDocument,
                    object: nil,
                    userInfo: ["documentId": docFile.id.uuidString, "toolName": "Templates"]
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.error()
            }
        }
    }
}
