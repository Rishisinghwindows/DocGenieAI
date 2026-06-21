//
//  InboxView.swift
//  DocGenieAI
//
//  Role: The home tab. Embodies the app's product story in two stacked halves:
//
//    1. **Universal search bar** at the top — semantic via SemanticSearchService.
//       Powered by NLEmbedding + keyword boost. The sparkle.magnifyingglass
//       glyph + AI shimmer rim signal "AI-powered" without saying it.
//
//    2. **Inbox cards** below — recently auto-organized docs from
//       AutoInboxService. Each card shows the AI's suggested name, summary,
//       tag, optional expiry, and one-tap "Looks good" / "Edit" controls.
//       Once accepted/edited, the card moves to the "Recent" compact list.
//
//  Cross-feature affordance: when a search returns 2+ results, a gradient
//  "Ask about these N documents" CTA appears, launching MultiDocQAView
//  pre-seeded with the result set. That's the seam where Inbox → Q&A flows.
//
//  Why this is the home tab (not Chat or Files): the auto-inbox is the
//  feature that turns Trove from a PDF utility into a paperless-inbox
//  product. Putting it first makes the magic moment the first thing
//  every user sees on launch.
//

import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router

    // Cards needing user review — ordered newest first.
    @Query(filter: #Predicate<DocumentFile> { $0.aiNeedsReview == true && $0.isInVault == false },
           sort: \DocumentFile.aiOrganizedAt, order: .reverse) private var pending: [DocumentFile]

    // Already-organized recent docs (background list when search is empty).
    @Query(filter: #Predicate<DocumentFile> { $0.aiNeedsReview == false && $0.isInVault == false },
           sort: \DocumentFile.importedAt, order: .reverse) private var recent: [DocumentFile]

    @State private var query: String = ""
    @State private var hits: [SearchHit] = []
    @State private var isSearching = false
    @State private var fileToEdit: DocumentFile?
    @State private var showQA = false
    @State private var qaSeedDocs: [DocumentFile] = []
    /// When non-nil, the rewarded-ad gate is presented for the multi-doc Q&A
    /// feature. Carries the docs to seed Q&A with on successful unlock.
    @State private var pendingQADocs: [DocumentFile]?
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        searchBar

                        if !query.isEmpty {
                            searchResults
                        } else {
                            if pending.isEmpty && recent.isEmpty {
                                emptyState
                            } else {
                                if !pending.isEmpty {
                                    pendingSection
                                }
                                if !recent.isEmpty {
                                    recentSection
                                }
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.md)
                }
                // Bottom adaptive banner. No-ops for Pro users.
                AdBannerView()
            }
            .background {
                // Subtle living-canvas mesh behind the header. Keeps the brand
                // alive without competing with content.
                AnimatedMeshBackground()
                    .opacity(0.18)
                    .frame(height: 380)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .overlay(Color.appBGDark.opacity(0.10))
                    .ignoresSafeArea()
                    .background(Color.appBGDark.ignoresSafeArea())
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.navigateToFiles()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .accessibilityLabel("All files")
                }
            }
            .onChange(of: query) { _, newValue in
                runSearch(for: newValue)
            }
            .sheet(item: $fileToEdit) { file in
                InboxEditSheet(file: file)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showQA) {
                MultiDocQAView(initialDocuments: qaSeedDocs)
            }
            // Rewarded-ad gate for Multi-doc Q&A. Same policy as everywhere
            // else: first use free, subsequent uses watch a short ad. Pro
            // users skip. Pending docs are seeded after a successful unlock.
            .sheet(isPresented: Binding(
                get: { pendingQADocs != nil },
                set: { if !$0 { pendingQADocs = nil } }
            )) {
                RewardedAdGateSheet(
                    toolName: "Ask your documents",
                    toolIcon: "sparkles",
                    onUnlock: {
                        FeatureGate.shared.recordUse(toolID: "inbox.multiDocQA")
                        if let docs = pendingQADocs {
                            qaSeedDocs = docs
                            pendingQADocs = nil
                            showQA = true
                        }
                    },
                    onCancel: { pendingQADocs = nil }
                )
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // Animated sparkle glyph signals "this is AI-powered search".
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.appPrimary, Color.appAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            TextField("Find anything…", text: $query)
                .font(.appBody)
                .foregroundStyle(Color.appText)
                .submitLabel(.search)
                .focused($searchFocused)
                .appWritingTools()

            if !query.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        query = ""
                        hits = []
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appTextDim)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .background(Color.appBGCard.opacity(0.6), in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        // AI shimmer rim turns on while focused — this is where the AI is "listening".
        .aiShimmerRim(isActive: searchFocused, cornerRadius: AppCornerRadius.lg, lineWidth: 1.2)
        .padding(.horizontal, AppSpacing.md)
        .scaleEffect(searchFocused ? 1.015 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: searchFocused)
    }

    // MARK: - Search results

    private var searchResults: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Text(hits.isEmpty
                     ? (isSearching ? "Searching…" : "No results")
                     : "\(hits.count) result\(hits.count == 1 ? "" : "s")")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
                Spacer()
                if SemanticSearchService.shared.isAvailable {
                    Label("Smart Search", systemImage: "sparkles")
                        .font(.appMicro)
                        .foregroundStyle(Color.appPrimary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.appPrimary.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, AppSpacing.md)

            ForEach(hits) { hit in
                SearchResultRow(hit: hit) {
                    HapticManager.light()
                    // Open document via existing router; for now, surface in Files tab.
                    router.navigateToFiles()
                }
                .padding(.horizontal, AppSpacing.md)
            }

            // "Ask about these results" — only when there are 2+ hits and on-device AI is feasible.
            if hits.count >= 2 {
                Button {
                    HapticManager.medium()
                    let docs = hits.map(\.document)
                    // Route through the gate: first Q&A is free, subsequent
                    // calls go through the rewarded-ad sheet.
                    switch FeatureGate.shared.evaluate(toolID: "inbox.multiDocQA") {
                    case .openFree:
                        FeatureGate.shared.recordUse(toolID: "inbox.multiDocQA")
                        qaSeedDocs = docs
                        showQA = true
                    case .needsRewardedAd:
                        pendingQADocs = docs
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.white)
                        Text("Ask about these \(hits.count) documents")
                            .font(.appBody.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.md)
                    .background(LinearGradient(colors: [Color.appPrimary, Color.appAccent],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Pending section

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader(title: "Just organized", subtitle: "Olea filed these for you. Tap a card if you'd like to tweak it.")
            ForEach(Array(pending.prefix(5).enumerated()), id: \.element.id) { _, file in
                InboxCard(file: file,
                          onConfirm: { confirm(file) },
                          onEdit: { fileToEdit = file })
                    .padding(.horizontal, AppSpacing.md)
                    .scrollTransition(.interactive.threshold(.visible(0.3))) { content, phase in
                        content
                            .opacity(1 - abs(phase.value) * 0.25)
                            .scaleEffect(1 - abs(phase.value) * 0.04)
                            .blur(radius: abs(phase.value) * 1.5)
                    }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader(title: "Recent", subtitle: nil)
            ForEach(recent.prefix(8)) { file in
                RecentRow(file: file)
                    .padding(.horizontal, AppSpacing.md)
                    .scrollTransition(.interactive.threshold(.visible(0.3))) { content, phase in
                        content
                            .opacity(1 - abs(phase.value) * 0.2)
                            .scaleEffect(1 - abs(phase.value) * 0.02)
                    }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.appCaption)
                .tracking(1)
                .foregroundStyle(Color.appTextMuted)
            if let subtitle {
                Text(subtitle)
                    .font(.appMicro)
                    .foregroundStyle(Color.appTextDim)
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Empty state

    @ViewBuilder
    private var trayBreathingIcon: some View {
        let baseIcon = Image(systemName: "tray.full")
            .font(.system(size: 38, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.appPrimary, Color.appAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        if #available(iOS 18, *) {
            baseIcon.symbolEffect(.breathe.plain.byLayer, options: .repeating)
        } else {
            baseIcon.symbolEffect(.pulse, options: .repeating)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            // Breathing tray inside the iridescent AI rim. Reads as "ready",
            // not "empty".
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.appPrimary.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 12)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 96, height: 96)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))

                trayBreathingIcon
            }
            .aiShimmerRim(cornerRadius: 60, lineWidth: 1.2)
            .padding(.top, AppSpacing.xl)

            Text("Your inbox is clear")
                .font(.appH3)
                .foregroundStyle(Color.appText)
                .padding(.top, AppSpacing.sm)

            Text("Scan or import a document and Olea will name, tag, and summarize it for you automatically.")
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }

    // MARK: - Actions

    private func confirm(_ file: DocumentFile) {
        if let suggested = file.aiSuggestedName, !suggested.isEmpty {
            file.name = suggested
        }
        file.aiNeedsReview = false
        try? modelContext.save()
        HapticManager.success()
    }

    private func runSearch(for raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hits = []
            isSearching = false
            return
        }
        isSearching = true
        // Tiny debounce-by-render: SwiftUI's @State change already coalesces typing.
        let results = SemanticSearchService.shared.search(query: trimmed, in: modelContext, limit: 20)
        hits = results
        isSearching = false
    }
}

// MARK: - Inbox card
//
// "Just organized" card. Hairline border + glass + iridescent AI rim so it reads
// as an AI-produced artifact, not a generic list cell. No drop shadows.

private struct InboxCard: View {
    let file: DocumentFile
    let onConfirm: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: contentTypeIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(LinearGradient(colors: [Color.appPrimary, Color.appAccent],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: AppCornerRadius.md))

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.aiSuggestedName ?? file.name)
                        .font(.appBody.bold())
                        .foregroundStyle(Color.appText)
                        .lineLimit(2)
                    HStack(spacing: AppSpacing.xs) {
                        if let tag = file.tag {
                            Label(tag.rawValue, systemImage: tag.icon)
                                .font(.appMicro)
                                .foregroundStyle(tag.color)
                        }
                        if let expiry = file.expiryDate {
                            Label(expiry.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                .font(.appMicro)
                                .foregroundStyle(Color.appWarning)
                        }
                    }
                }
                Spacer()
                // Tiny sparkles in the corner — "this came from AI"
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appPrimary)
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
            }

            if let summary = file.aiSummary, !summary.isEmpty {
                Text(summary)
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
                    .lineLimit(3)
            }

            HStack(spacing: AppSpacing.sm) {
                Button {
                    onConfirm()
                } label: {
                    Label("Looks good", systemImage: "checkmark.circle.fill")
                        .font(.appCaption.bold())
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color.appPrimary, Color.appAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: AppCornerRadius.md)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.appCaption.bold())
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
                        .foregroundStyle(Color.appText)
                        .hairline(cornerRadius: AppCornerRadius.md)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .background(Color.appBGCard.opacity(0.7), in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .aiShimmerRim(isActive: true, cornerRadius: AppCornerRadius.lg, lineWidth: 1.0)
    }

    private var contentTypeIcon: String {
        switch file.aiContentType {
        case "receipt": return "receipt"
        case "invoice": return "doc.text"
        case "letter": return "envelope"
        case "contract": return "doc.text.below.ecg"
        case "id": return "person.text.rectangle"
        case "form": return "doc.plaintext"
        case "statement": return "chart.bar.doc.horizontal"
        default: return "doc"
        }
    }
}

// MARK: - Recent row (compact, no actions)

private struct RecentRow: View {
    let file: DocumentFile

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: file.tag?.icon ?? "doc")
                .foregroundStyle(file.tag?.color ?? Color.appTextDim)
                .frame(width: 32, height: 32)
                .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(file.aiSuggestedName ?? file.name)
                    .font(.appBody)
                    .foregroundStyle(Color.appText)
                    .lineLimit(1)
                if let summary = file.aiSummary {
                    Text(summary)
                        .font(.appMicro)
                        .foregroundStyle(Color.appTextMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Text(file.importedAt.formatted(.relative(presentation: .numeric)))
                .font(.appMicro)
                .foregroundStyle(Color.appTextDim)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBGCard.opacity(0.5), in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
    }
}

// MARK: - Search result row

private struct SearchResultRow: View {
    let hit: SearchHit
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: hit.document.tag?.icon ?? "doc")
                    .foregroundStyle(hit.document.tag?.color ?? Color.appTextDim)
                    .frame(width: 36, height: 36)
                    .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.document.aiSuggestedName ?? hit.document.name)
                        .font(.appBody.bold())
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)
                    Text(hit.snippet)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.sm)
            .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inbox edit sheet

private struct InboxEditSheet: View {
    @Bindable var file: DocumentFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Document name", text: Binding(
                        get: { file.aiSuggestedName ?? file.name },
                        set: { file.aiSuggestedName = $0 }
                    ))
                    .appWritingTools()
                }
                Section("Tag") {
                    Picker("Tag", selection: Binding(
                        get: { file.tag ?? .archive },
                        set: { file.tagName = $0.rawValue }
                    )) {
                        ForEach(FileTag.allCases) { tag in
                            Label(tag.rawValue, systemImage: tag.icon).tag(tag)
                        }
                    }
                }
                if let summary = file.aiSummary, !summary.isEmpty {
                    Section("AI summary") {
                        Text(summary)
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextMuted)
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let suggested = file.aiSuggestedName, !suggested.isEmpty {
                            file.name = suggested
                        }
                        file.aiNeedsReview = false
                        try? modelContext.save()
                        HapticManager.success()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
