import SwiftUI
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

struct SmartCategorizeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DocumentFile> { $0.tagName == nil && $0.isInVault == false },
           sort: \DocumentFile.importedAt, order: .reverse) private var untagged: [DocumentFile]
    private static let analysisLimit = 200

    @State private var suggestions: [Suggestion] = []
    @State private var isAnalyzing = false
    @State private var hasAnalyzed = false
    @State private var appliedCount = 0
    @State private var didComplete = false

    var body: some View {
        NavigationStack {
            Group {
                if !hasAnalyzed {
                    introView
                } else if suggestions.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.seal",
                        title: "Nothing to Categorize",
                        message: "All your files already have tags or no confident suggestions could be made."
                    )
                } else {
                    suggestionsList
                }
            }
            .background(Color.appBGDark)
            .navigationTitle("Smart Categorize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !suggestions.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply All") { applyAll() }
                            .disabled(suggestions.allSatisfy { !$0.isSelected })
                    }
                }
            }
            .confettiOnComplete(didComplete)
        }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Color.appPrimary)
                .symbolEffect(.pulse, options: .repeating)
            VStack(spacing: AppSpacing.sm) {
                Text("Auto-tag your documents")
                    .font(.appH2)
                    .foregroundStyle(Color.appText)
                Text("Olea will scan untagged files (\(untagged.count)) and suggest the best tag based on their content. Everything runs on-device.")
                    .font(.appBody)
                    .foregroundStyle(Color.appTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            if isAnalyzing {
                ProgressView()
                    .padding(.top, AppSpacing.md)
            } else {
                Button {
                    analyze()
                } label: {
                    Label("Analyze \(untagged.count) Files", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color.appPrimary)
                .padding(.horizontal, AppSpacing.xl)
                .disabled(untagged.isEmpty)
            }
            Spacer()
        }
    }

    // MARK: - Suggestions list

    private var suggestionsList: some View {
        List {
            Section {
                ForEach($suggestions) { $suggestion in
                    SuggestionRow(suggestion: $suggestion)
                }
            } footer: {
                if appliedCount > 0 {
                    Text("Applied to \(appliedCount) file\(appliedCount == 1 ? "" : "s").")
                        .foregroundStyle(Color.appSuccess)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Analyze

    private func analyze() {
        isAnalyzing = true
        // Snapshot SwiftData @Model fields into value tuples *before* spawning the Task,
        // so the async closure never re-touches a potentially-faulted persistent object.
        let snapshots: [(id: UUID, name: String, fullFileName: String, ocr: String)] =
            untagged.prefix(Self.analysisLimit).map { file in
                (file.id, file.name, file.fullFileName, file.ocrTextCache ?? "")
            }
        Task {
            var results: [Suggestion] = []
            for snap in snapshots {
                let categorization = AutoCategorizeService.shared.categorize(ocrText: snap.ocr, fileName: snap.name)
                if let tag = categorization.suggestedTag, categorization.confidence >= 0.5 {
                    results.append(Suggestion(
                        id: snap.id,
                        fileName: snap.fullFileName,
                        tag: tag,
                        confidence: categorization.confidence,
                        suggestedName: categorization.suggestedName,
                        isSelected: true
                    ))
                }
            }
            suggestions = results
            isAnalyzing = false
            hasAnalyzed = true
            HapticManager.success()
        }
    }

    private func applyAll() {
        let toApply = suggestions.filter(\.isSelected)
        for suggestion in toApply {
            guard let file = untagged.first(where: { $0.id == suggestion.id }) else { continue }
            file.tagName = suggestion.tag.rawValue
        }
        try? modelContext.save()
        appliedCount = toApply.count
        suggestions.removeAll { $0.isSelected }
        didComplete = true
        HapticManager.success()
    }
}

// MARK: - Suggestion model

private struct Suggestion: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let tag: FileTag
    let confidence: Double
    let suggestedName: String?
    var isSelected: Bool
}

// MARK: - Row

private struct SuggestionRow: View {
    @Binding var suggestion: Suggestion

    var body: some View {
        Button {
            suggestion.isSelected.toggle()
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: suggestion.tag.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(suggestion.tag.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.fileName)
                        .font(.appBody)
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)
                    HStack(spacing: AppSpacing.xs) {
                        Text(suggestion.tag.localizedName)
                            .font(.appMicro)
                            .foregroundStyle(suggestion.tag.color)
                        Text("·")
                            .foregroundStyle(Color.appTextDim)
                        Text("\(Int(suggestion.confidence * 100))% confidence")
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextMuted)
                    }
                }

                Spacer()

                Image(systemName: suggestion.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(suggestion.isSelected ? Color.appPrimary : Color.appTextDim)
                    .font(.system(size: 22))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
