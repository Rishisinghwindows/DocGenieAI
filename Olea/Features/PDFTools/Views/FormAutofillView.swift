//
//  FormAutofillView.swift
//  DocGenieAI
//
//  Role: UI for the Smart Form Autofill tool. State-machine layout that
//  walks the user through four phases:
//
//      .choose     → user picks a fillable PDF + sees "how it works"
//      .analyzing  → animated hero while FormAutofillService runs FM + OCR
//      .review     → per-field cards with confidence ring, source-doc
//                    citation, accept toggle, "Why this value?" disclosure
//      .done       → success state with bounce + confetti
//
//  Each phase has its own transition (`.opacity.combined(with: .scale)`) so
//  the user perceives the flow as one continuous animation rather than
//  separate screens.
//
//  Design vocabulary used (see AppleIntelligenceComponents.swift):
//      • AnimatedMeshBackground   — backdrop
//      • aiShimmerRim()           — on hero icon, picker card, summary card,
//                                    each accepted suggestion card
//      • .ultraThinMaterial + .hairline() — instead of drop shadows
//      • .symbolEffect(.variableColor.iterative.reversing) — sparkles
//      • .symbolEffect(.bounce, value:) — success bounce
//      • .scrollTransition         — micro-fade + scale + blur on rows
//
//  Service contract: this view is purely presentational. All field detection,
//  Foundation Models calls, and PDF write-back live in FormAutofillService.
//

import SwiftUI
import SwiftData
import PDFKit

struct FormAutofillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedFiles: [DocumentFile] = []
    @State private var showPicker = false
    @State private var phase: Phase = .choose
    @State private var result: FormAutofillService.AnalysisResult?
    @State private var suggestions: [FormAutofillService.FieldSuggestion] = []
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var savedFileName: String?
    @State private var outputName = ""
    @State private var analyzingStep: Int = 0
    @State private var expandedSuggestionID: UUID?
    @State private var doneBounceTrigger: Int = 0

    private enum Phase { case choose, analyzing, review, done }

    private var selectedFile: DocumentFile? { selectedFiles.first }
    private var acceptedCount: Int { suggestions.filter(\.isAccepted).count }

    var body: some View {
        NavigationStack {
            ZStack {
                backdrop
                contentForPhase
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showPicker) {
                PDFFilePickerView(title: "Select form", allowsMultiple: false, selectedFiles: $selectedFiles)
            }
            .onChange(of: selectedFiles) { _, _ in
                if let f = selectedFile { outputName = "\(f.name) (filled)" }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: { Text(errorMessage ?? "Something went wrong.") }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: phase)
        }
    }

    // MARK: - Backdrop

    /// Subtle living-canvas mesh fading into the app's dark background. Keeps
    /// the Form Fill flow visually tied to Inbox + Onboarding.
    private var backdrop: some View {
        ZStack {
            Color.appBGDark.ignoresSafeArea()
            AnimatedMeshBackground()
                .opacity(0.18)
                .frame(height: 420)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
        }
    }

    // MARK: - Phase router

    @ViewBuilder
    private var contentForPhase: some View {
        switch phase {
        case .choose:    chooseView
        case .analyzing: analyzingView
        case .review:    reviewView
        case .done:      doneView
        }
    }

    private var navigationTitle: String {
        switch phase {
        case .choose:    return "Smart Form Fill"
        case .analyzing: return "Reading…"
        case .review:    return "Review"
        case .done:      return "Done"
        }
    }

    // MARK: - Choose

    private var chooseView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                heroIcon

                VStack(spacing: AppSpacing.sm) {
                    Text("Auto-fill any form")
                        .font(.system(size: 28, weight: .bold))
                        .kerning(-0.3)
                        .foregroundStyle(Color.appText)
                        .multilineTextAlignment(.center)
                    Text("Pick a fillable PDF. Apple Intelligence reads each field and pulls the right values from your library.")
                        .font(.appBody)
                        .foregroundStyle(Color.appTextMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.top, AppSpacing.sm)

                pickerCard

                howItWorksCard

                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
        }
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.appPrimary.opacity(0.30), .clear],
                                      center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 220, height: 220)
                .blur(radius: 18)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 128, height: 128)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8))

            Image(systemName: "square.and.pencil")
                .font(.system(size: 50, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: [Color.appPrimary, Color.appAccent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .applyBreath()
        }
        .aiShimmerRim(cornerRadius: 80, lineWidth: 1.6)
        .padding(.top, AppSpacing.md)
    }

    private var pickerCard: some View {
        Button {
            HapticManager.light()
            showPicker = true
        } label: {
            HStack(spacing: AppSpacing.md) {
                if let file = selectedFile {
                    FileTypeIcon(fileExtension: "pdf")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.fullFileName)
                            .font(.appBody.bold())
                            .foregroundStyle(Color.appText)
                            .lineLimit(1)
                        Text(file.fileSize.formattedFileSize)
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextDim)
                    }
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.appCaption)
                        .foregroundStyle(Color.appPrimary)
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.appPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.appPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose a fillable PDF")
                            .font(.appBody.bold())
                            .foregroundStyle(Color.appText)
                        Text("Forms with text fields you can tap to fill")
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextDim)
                }
            }
            .padding(AppSpacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
            .background(Color.appBGCard.opacity(0.6), in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
            .aiShimmerRim(isActive: selectedFile != nil, cornerRadius: AppCornerRadius.lg, lineWidth: 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("HOW IT WORKS")
                .font(.appMicro.bold())
                .tracking(1.2)
                .foregroundStyle(Color.appTextMuted)
                .padding(.bottom, AppSpacing.xs)
            howStep(number: "1", icon: "doc.text.magnifyingglass",
                     title: "Read every fillable field",
                     subtitle: "Names, addresses, dates, signatures — Olea finds them all.")
            howStep(number: "2", icon: "sparkles",
                     title: "Cross-reference your library",
                     subtitle: "Apple Intelligence finds the matching values from your existing documents.")
            howStep(number: "3", icon: "checkmark.seal.fill",
                     title: "Review with sources",
                     subtitle: "Every suggestion shows where it came from. You approve before saving.")
        }
        .padding(AppSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .background(Color.appBGCard.opacity(0.5), in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .hairline(cornerRadius: AppCornerRadius.lg)
    }

    private func howStep(number: String, icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.16))
                    .frame(width: 32, height: 32)
                Text(number)
                    .font(.appCaption.bold())
                    .foregroundStyle(Color.appPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundStyle(Color.appAccent)
                        .font(.appCaption)
                    Text(title)
                        .font(.appBody.bold())
                        .foregroundStyle(Color.appText)
                }
                Text(subtitle)
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Analyzing

    private var analyzingView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            ZStack {
                // Outer pulsing halo
                Circle()
                    .stroke(
                        LinearGradient(colors: [Color.appPrimary.opacity(0.4), Color.appAccent.opacity(0.4)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(analyzingStep % 2 == 0 ? 1.05 : 0.95)
                    .opacity(0.6)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: analyzingStep)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 140, height: 140)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))

                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .medium))
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                    .foregroundStyle(
                        LinearGradient(colors: [Color.appPrimary, Color.appAccent],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .aiShimmerRim(cornerRadius: 100, lineWidth: 1.8)

            VStack(spacing: AppSpacing.md) {
                Text(analyzingStepText)
                    .font(.appH3)
                    .foregroundStyle(Color.appText)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: analyzingStep)
                Text("This usually takes a few seconds. Nothing leaves your device.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await driveAnalyzingSteps()
        }
    }

    private var analyzingStepText: String {
        switch analyzingStep {
        case 0: return "Reading the form fields…"
        case 1: return "Searching your library…"
        case 2: return "Cross-referencing values…"
        default: return "Almost ready…"
        }
    }

    private func driveAnalyzingSteps() async {
        while phase == .analyzing {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                if analyzingStep < 3 { analyzingStep += 1 }
            }
        }
    }

    // MARK: - Review

    private var reviewView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                summaryCard
                outputNameField

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("SUGGESTED VALUES")
                            .font(.appMicro.bold())
                            .tracking(1.2)
                            .foregroundStyle(Color.appTextMuted)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.sm)

                        ForEach($suggestions) { $sug in
                            SuggestionCard(suggestion: $sug,
                                           isExpanded: expandedSuggestionID == sug.id,
                                           onToggleExpand: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    expandedSuggestionID = expandedSuggestionID == sug.id ? nil : sug.id
                                }
                            })
                            .padding(.horizontal, AppSpacing.md)
                            .scrollTransition(.interactive.threshold(.visible(0.3))) { content, phase in
                                content
                                    .opacity(1 - abs(phase.value) * 0.25)
                                    .scaleEffect(1 - abs(phase.value) * 0.03)
                                    .blur(radius: abs(phase.value) * 1.5)
                            }
                        }
                    }
                }

                if let unfilled = result?.unfilledFields, !unfilled.isEmpty {
                    unfilledSection(unfilled)
                }

                Spacer(minLength: AppSpacing.xxl)
            }
            .padding(.vertical, AppSpacing.md)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.appPrimary.opacity(0.25), Color.appAccent.opacity(0.25)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                    .foregroundStyle(
                        LinearGradient(colors: [Color.appPrimary, Color.appAccent],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(acceptedCount) of \(suggestions.count) fields ready")
                    .font(.appBody.bold())
                    .foregroundStyle(Color.appText)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: acceptedCount)
                Text(result?.usedFoundationModels == true
                     ? "Apple Intelligence · grounded in your library"
                     : "Basic mode · keyword match only")
                    .font(.appMicro)
                    .foregroundStyle(Color.appTextMuted)
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .background(Color.appBGCard.opacity(0.6), in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .aiShimmerRim(cornerRadius: AppCornerRadius.lg, lineWidth: 1.0)
        .padding(.horizontal, AppSpacing.md)
    }

    private var outputNameField: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "doc.badge.plus")
                .foregroundStyle(Color.appPrimary)
            TextField("Filled form name", text: $outputName)
                .font(.appBody)
                .appWritingTools()
        }
        .padding(AppSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
        .hairline(cornerRadius: AppCornerRadius.md)
        .padding(.horizontal, AppSpacing.md)
    }

    private func unfilledSection(_ fields: [FormAutofillService.PDFFormField]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("COULDN'T FIND  ·  \(fields.count)")
                .font(.appMicro.bold())
                .tracking(1.2)
                .foregroundStyle(Color.appWarning)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)

            VStack(spacing: AppSpacing.xs) {
                ForEach(fields) { field in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(Color.appWarning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.label.isEmpty ? field.name : field.label)
                                .font(.appBody)
                                .foregroundStyle(Color.appText)
                            Text("Fill manually after saving")
                                .font(.appMicro)
                                .foregroundStyle(Color.appTextMuted)
                        }
                        Spacer()
                    }
                    .padding(AppSpacing.sm)
                }
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xs)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
            .hairline(cornerRadius: AppCornerRadius.md)
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.appSuccess.opacity(0.30), .clear],
                                          center: .center, startRadius: 0, endRadius: 110))
                    .frame(width: 220, height: 220)
                    .blur(radius: 18)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 128, height: 128)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Color.appSuccess.gradient)
                    // Trigger-driven bounce — iOS 17 compatible. Toggling the
                    // Int triggers a single bounce animation on mount.
                    .symbolEffect(.bounce, value: doneBounceTrigger)
                    .task { doneBounceTrigger += 1 }
            }
            .aiShimmerRim(cornerRadius: 80, lineWidth: 1.6)

            VStack(spacing: AppSpacing.sm) {
                Text("All set")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.appText)
                if let name = savedFileName {
                    Text("Saved as \(name)")
                        .font(.appBody)
                        .foregroundStyle(Color.appTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
                Text("Open from Files to sign or share.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextDim)
                    .padding(.top, AppSpacing.xs)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.appBody.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Color.appPrimary, Color.appAccent],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: AppCornerRadius.md)
                    )
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
        .confettiOnComplete(phase == .done)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if phase != .done {
                Button("Cancel") { dismiss() }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            switch phase {
            case .choose:
                Button("Analyze") { Task { await analyze() } }
                    .disabled(selectedFile == nil)
                    .bold()
            case .analyzing:
                ProgressView()
            case .review:
                Button("Save") { save() }
                    .disabled(acceptedCount == 0 || outputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .bold()
            case .done:
                EmptyView()
            }
        }
    }

    // MARK: - Actions

    private func analyze() async {
        guard let url = selectedFile?.fileURL else { return }
        withAnimation { phase = .analyzing; analyzingStep = 0 }
        do {
            let analysis = try await FormAutofillService.shared.analyze(pdfURL: url, modelContext: modelContext)
            if analysis.suggestions.isEmpty && analysis.unfilledFields.isEmpty {
                errorMessage = "This PDF has no fillable fields. It might be a scanned form rather than a true PDF form."
                showError = true
                withAnimation { phase = .choose }
                return
            }
            result = analysis
            suggestions = analysis.suggestions
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { phase = .review }
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            withAnimation { phase = .choose }
            HapticManager.error()
        }
    }

    private func save() {
        guard let originalURL = selectedFile?.fileURL else { return }
        let trimmedName = outputName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let dir = FileStorageService.shared.appFilesDirectory
        var destinationURL = dir.appendingPathComponent("\(trimmedName).pdf")
        var counter = 1
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            destinationURL = dir.appendingPathComponent("\(trimmedName) (\(counter)).pdf")
            counter += 1
        }

        do {
            _ = try FormAutofillService.shared.savedFilledPDF(
                originalURL: originalURL,
                suggestions: suggestions,
                to: destinationURL
            )
            let relativePath = AppConstants.appDocumentsSubdirectory + "/" + destinationURL.lastPathComponent
            let metadata = FileMetadataService.shared.extractMetadata(from: destinationURL)
            let docFile = DocumentFile(
                name: trimmedName,
                fileExtension: "pdf",
                relativeFilePath: relativePath,
                fileSize: metadata.fileSize,
                pageCount: metadata.pageCount
            )
            modelContext.insert(docFile)
            try modelContext.save()

            savedFileName = trimmedName
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { phase = .done }
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.error()
        }
    }
}

// MARK: - Suggestion card

private struct SuggestionCard: View {
    @Binding var suggestion: FormAutofillService.FieldSuggestion
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    private var confidenceTint: Color {
        switch suggestion.confidence {
        case 0.8...: return .appSuccess
        case 0.5...: return .appWarning
        default:     return .appTextMuted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(confidenceTint.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Circle()
                        .trim(from: 0, to: suggestion.confidence)
                        .stroke(confidenceTint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(suggestion.confidence * 100))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(confidenceTint)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: suggestion.confidence)

                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.field.label.isEmpty ? suggestion.field.name : suggestion.field.label)
                        .font(.appCaption.bold())
                        .foregroundStyle(Color.appTextMuted)
                        .tracking(0.2)
                    if let source = suggestion.sourceDocumentName {
                        Label(source, systemImage: "doc.text")
                            .font(.appMicro)
                            .foregroundStyle(Color.appAccent)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Toggle("", isOn: $suggestion.isAccepted)
                    .labelsHidden()
                    .tint(Color.appPrimary)
                    .scaleEffect(0.85)
            }

            TextField("Value", text: $suggestion.value)
                .font(.appBody)
                .foregroundStyle(Color.appText)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 10)
                .background(Color.appBGDark.opacity(0.45), in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))
                .hairline(cornerRadius: AppCornerRadius.sm)
                .opacity(suggestion.isAccepted ? 1 : 0.35)
                .disabled(!suggestion.isAccepted)
                .appWritingTools()

            if isExpanded, !suggestion.reasoning.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.appMicro)
                        .foregroundStyle(Color.appAccent)
                        .padding(.top, 1)
                    Text(suggestion.reasoning)
                        .font(.appMicro)
                        .foregroundStyle(Color.appTextMuted)
                        .lineLimit(3)
                }
                .padding(AppSpacing.sm)
                .background(Color.appAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack {
                if !suggestion.reasoning.isEmpty {
                    Button {
                        HapticManager.light()
                        onToggleExpand()
                    } label: {
                        Label(isExpanded ? "Hide reasoning" : "Why this value?", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.appMicro.bold())
                            .foregroundStyle(Color.appPrimary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .background(Color.appBGCard.opacity(0.55), in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .aiShimmerRim(isActive: suggestion.isAccepted, cornerRadius: AppCornerRadius.lg, lineWidth: 0.9)
        .opacity(suggestion.isAccepted ? 1 : 0.7)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: suggestion.isAccepted)
    }
}

// MARK: - Breathing helper

private extension View {
    @ViewBuilder
    func applyBreath() -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.breathe.plain.byLayer, options: .repeating)
        } else {
            self.symbolEffect(.pulse, options: .repeating)
        }
    }

}
