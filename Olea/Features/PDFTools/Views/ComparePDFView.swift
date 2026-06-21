import SwiftUI
import PDFKit

// MARK: - Diff Model

struct DiffLine: Identifiable {
    let id = UUID()
    let text: String
    let type: DiffType

    enum DiffType {
        case unchanged
        case addition
        case deletion
    }

    var color: Color {
        switch type {
        case .unchanged: return .appText
        case .addition: return .appSuccess
        case .deletion: return .appDanger
        }
    }

    var prefix: String {
        switch type {
        case .unchanged: return "  "
        case .addition: return "+ "
        case .deletion: return "- "
        }
    }

    var backgroundColor: Color {
        switch type {
        case .unchanged: return .clear
        case .addition: return .appSuccess.opacity(0.1)
        case .deletion: return .appDanger.opacity(0.1)
        }
    }
}

struct DiffStats {
    var additions: Int = 0
    var deletions: Int = 0
    var unchanged: Int = 0

    var totalChanges: Int { additions + deletions }
}

// MARK: - View

struct ComparePDFView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilesA: [DocumentFile] = []
    @State private var selectedFilesB: [DocumentFile] = []
    @State private var showPickerA = false
    @State private var showPickerB = false
    @State private var isProcessing = false
    @State private var didComplete = false
    @State private var diffLines: [DiffLine] = []
    @State private var stats = DiffStats()
    @State private var showUnifiedDiff = true
    @State private var errorMessage: String?
    @State private var showError = false

    private var fileA: DocumentFile? { selectedFilesA.first }
    private var fileB: DocumentFile? { selectedFilesB.first }

    var body: some View {
        NavigationStack {
            Group {
                if didComplete {
                    resultView
                } else if isProcessing {
                    processingView
                } else {
                    formView
                }
            }
            .navigationTitle("Compare PDFs")
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
                    } else {
                        Button("Compare") { compare() }
                            .disabled(fileA == nil || fileB == nil)
                    }
                }
            }
            .sheet(isPresented: $showPickerA) {
                PDFFilePickerView(
                    title: "Select First PDF",
                    allowsMultiple: false,
                    selectedFiles: $selectedFilesA
                )
            }
            .sheet(isPresented: $showPickerB) {
                PDFFilePickerView(
                    title: "Select Second PDF",
                    allowsMultiple: false,
                    selectedFiles: $selectedFilesB
                )
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
        }
    }

    // MARK: - Form View

    private var formView: some View {
        Form {
            Section("First Document") {
                Button { showPickerA = true } label: {
                    if let file = fileA {
                        HStack {
                            FileTypeIcon(fileExtension: "pdf")
                            VStack(alignment: .leading) {
                                Text(file.fullFileName)
                                    .font(.appBody)
                                    .lineLimit(1)
                                Text(file.fileSize.formattedFileSize)
                                    .font(.appCaption)
                                    .foregroundStyle(Color.appTextDim)
                            }
                        }
                    } else {
                        Label("Choose first PDF", systemImage: "doc.richtext")
                            .font(.appBody)
                    }
                }
            }

            Section("Second Document") {
                Button { showPickerB = true } label: {
                    if let file = fileB {
                        HStack {
                            FileTypeIcon(fileExtension: "pdf")
                            VStack(alignment: .leading) {
                                Text(file.fullFileName)
                                    .font(.appBody)
                                    .lineLimit(1)
                                Text(file.fileSize.formattedFileSize)
                                    .font(.appCaption)
                                    .foregroundStyle(Color.appTextDim)
                            }
                        }
                    } else {
                        Label("Choose second PDF", systemImage: "doc.richtext")
                            .font(.appBody)
                    }
                }
            }

            Section {
                Text("Select two PDF documents to compare their text content. Differences will be highlighted line by line.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
            }
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Extracting and comparing text...")
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBGDark)
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: 0) {
            // Stats bar
            statsBar

            // Toggle
            Picker("View Mode", selection: $showUnifiedDiff) {
                Text("Unified").tag(true)
                Text("Side by Side").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)

            Divider()

            if diffLines.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No Differences",
                    message: "Both documents have identical text content."
                )
            } else if showUnifiedDiff {
                unifiedDiffView
            } else {
                sideBySideView
            }
        }
        .background(Color.appBGDark)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: AppSpacing.lg) {
            statItem(label: "Changes", value: "\(stats.totalChanges)", color: .appWarning)
            statItem(label: "Additions", value: "+\(stats.additions)", color: .appSuccess)
            statItem(label: "Deletions", value: "-\(stats.deletions)", color: .appDanger)
            statItem(label: "Unchanged", value: "\(stats.unchanged)", color: .appTextMuted)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBGCard)
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .font(.appH3)
                .foregroundStyle(color)
            Text(label)
                .font(.appMicro)
                .foregroundStyle(Color.appTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Unified Diff View

    private var unifiedDiffView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(diffLines) { line in
                    HStack(spacing: 0) {
                        Text(line.prefix)
                            .font(.appMono)
                            .foregroundStyle(line.color)
                            .frame(width: 24, alignment: .leading)

                        Text(line.text)
                            .font(.appMono)
                            .foregroundStyle(line.color)
                            .textSelection(.enabled)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 2)
                    .background(line.backgroundColor)
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
    }

    // MARK: - Side by Side View

    private var sideBySideView: some View {
        let leftLines = diffLines.filter { $0.type != .addition }
        let rightLines = diffLines.filter { $0.type != .deletion }

        return HStack(spacing: 0) {
            // Left side (Document 1)
            VStack(spacing: 0) {
                Text(fileA?.name ?? "Document 1")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
                    .padding(.vertical, AppSpacing.xs)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(leftLines) { line in
                            Text(line.text)
                                .font(.appMono)
                                .foregroundStyle(line.type == .deletion ? Color.appDanger : Color.appText)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(line.type == .deletion ? Color.appDanger.opacity(0.1) : .clear)
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
            }

            Divider()

            // Right side (Document 2)
            VStack(spacing: 0) {
                Text(fileB?.name ?? "Document 2")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
                    .padding(.vertical, AppSpacing.xs)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rightLines) { line in
                            Text(line.text)
                                .font(.appMono)
                                .foregroundStyle(line.type == .addition ? Color.appSuccess : Color.appText)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(line.type == .addition ? Color.appSuccess.opacity(0.1) : .clear)
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
    }

    // MARK: - Compare Logic

    private func compare() {
        guard let urlA = fileA?.fileURL, let urlB = fileB?.fileURL else { return }
        isProcessing = true
        HapticManager.light()

        Task {
            do {
                async let textA = OCRService.shared.extractText(from: urlA)
                async let textB = OCRService.shared.extractText(from: urlB)

                let (resultA, resultB) = try await (textA, textB)
                let linesA = resultA.components(separatedBy: .newlines)
                let linesB = resultB.components(separatedBy: .newlines)

                let result = computeDiff(linesA: linesA, linesB: linesB)

                await MainActor.run {
                    diffLines = result.lines
                    stats = result.stats
                    isProcessing = false
                    didComplete = true
                    HapticManager.success()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.error()
                }
            }
        }
    }

    private func computeDiff(linesA: [String], linesB: [String]) -> (lines: [DiffLine], stats: DiffStats) {
        let setA = Set(linesA)
        let setB = Set(linesB)

        var result: [DiffLine] = []
        var stats = DiffStats()

        // Build a simple LCS-style line diff using two pointers
        // and set membership for classification
        var indexA = 0
        var indexB = 0

        while indexA < linesA.count && indexB < linesB.count {
            let lineA = linesA[indexA]
            let lineB = linesB[indexB]

            if lineA == lineB {
                // Lines match
                result.append(DiffLine(text: lineA, type: .unchanged))
                stats.unchanged += 1
                indexA += 1
                indexB += 1
            } else if !setB.contains(lineA) {
                // lineA is not in B at all => deletion
                result.append(DiffLine(text: lineA, type: .deletion))
                stats.deletions += 1
                indexA += 1
            } else if !setA.contains(lineB) {
                // lineB is not in A at all => addition
                result.append(DiffLine(text: lineB, type: .addition))
                stats.additions += 1
                indexB += 1
            } else {
                // Both lines exist in each other's document but at different positions.
                // Look ahead to decide which to consume first.
                // Try to find lineB in remaining A lines
                let lookAheadA = linesA[(indexA + 1)...].prefix(10)
                let lookAheadB = linesB[(indexB + 1)...].prefix(10)

                if lookAheadA.contains(lineB) {
                    // lineA appears to be deleted before we reach lineB
                    result.append(DiffLine(text: lineA, type: .deletion))
                    stats.deletions += 1
                    indexA += 1
                } else if lookAheadB.contains(lineA) {
                    // lineB appears to be added before we reach lineA
                    result.append(DiffLine(text: lineB, type: .addition))
                    stats.additions += 1
                    indexB += 1
                } else {
                    // Default: treat as deletion then addition
                    result.append(DiffLine(text: lineA, type: .deletion))
                    stats.deletions += 1
                    indexA += 1
                    result.append(DiffLine(text: lineB, type: .addition))
                    stats.additions += 1
                    indexB += 1
                }
            }
        }

        // Remaining lines in A are deletions
        while indexA < linesA.count {
            result.append(DiffLine(text: linesA[indexA], type: .deletion))
            stats.deletions += 1
            indexA += 1
        }

        // Remaining lines in B are additions
        while indexB < linesB.count {
            result.append(DiffLine(text: linesB[indexB], type: .addition))
            stats.additions += 1
            indexB += 1
        }

        return (result, stats)
    }
}
