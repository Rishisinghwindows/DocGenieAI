//
//  MultiDocQAView.swift
//  DocGenieAI
//
//  Role: NotebookLM-style multi-document Q&A surface. The user picks N
//  documents (or arrives pre-seeded from Inbox search), types a question,
//  and gets a Foundation Models-grounded answer with structured citations
//  that link back to the source documents.
//
//  Why this exists separately from the Chat ("Ask") tab: chat is conversational
//  and free-form. Q&A is *grounded* — strictly answers from the supplied
//  documents, with citations the user can verify. Two different mental models,
//  two different surfaces.
//
//  Citation UX: each citation chip opens a CitationDetailView showing the
//  exact phrase the model used + the doc summary. This is the trust layer
//  that makes the answer worth trusting; without it the AI is a black box.
//
//  Backed by: MultiDocQAService (see file header there for pipeline details).
//

import SwiftUI
import SwiftData

struct MultiDocQAView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Documents pre-selected by the caller (e.g. from search results). The user
    /// can add or remove from this set.
    let initialDocuments: [DocumentFile]

    @Query(sort: \DocumentFile.importedAt, order: .reverse) private var allDocs: [DocumentFile]

    @State private var question: String = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var showPicker = false
    @State private var isWorking = false
    @State private var answer: MultiDocQAService.Answer?
    @State private var citationToOpen: MultiDocQAService.Citation?

    private var selectedDocuments: [DocumentFile] {
        allDocs.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    selectedDocsCard

                    questionField

                    if isWorking {
                        ProgressView("Reading your documents…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.lg)
                    } else if let answer {
                        answerCard(answer)
                    } else {
                        suggestionPrompts
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(Color.appBGDark.ignoresSafeArea())
            .navigationTitle("Ask your docs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await ask() }
                    } label: {
                        if isWorking {
                            ProgressView()
                        } else {
                            Text("Ask").bold()
                        }
                    }
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedIDs.isEmpty || isWorking)
                }
            }
            .sheet(isPresented: $showPicker) {
                MultiDocPicker(allDocs: allDocs, selected: $selectedIDs)
                    .presentationDetents([.large])
            }
            .sheet(item: $citationToOpen) { citation in
                CitationDetailView(citation: citation, modelContext: modelContext)
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                if selectedIDs.isEmpty {
                    selectedIDs = Set(initialDocuments.map(\.id))
                }
            }
        }
    }

    // MARK: - Selected docs card

    private var selectedDocsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Label("Asking about", systemImage: "doc.on.doc")
                    .font(.appCaption.bold())
                    .foregroundStyle(Color.appTextMuted)
                Spacer()
                Button {
                    showPicker = true
                } label: {
                    Text("Pick docs")
                        .font(.appCaption.bold())
                        .foregroundStyle(Color.appPrimary)
                }
            }

            if selectedDocuments.isEmpty {
                Text("No documents selected. Tap 'Pick docs' to choose.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextDim)
            } else {
                ForEach(selectedDocuments) { doc in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: doc.tag?.icon ?? "doc")
                            .foregroundStyle(doc.tag?.color ?? Color.appTextDim)
                            .frame(width: 24)
                        Text(doc.aiSuggestedName ?? doc.name)
                            .font(.appCaption)
                            .foregroundStyle(Color.appText)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            selectedIDs.remove(doc.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.appTextDim)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
    }

    // MARK: - Question field

    private var questionField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Your question")
                .font(.appCaption.bold())
                .foregroundStyle(Color.appTextMuted)
            TextField("e.g. What's the difference between these contracts?",
                      text: $question, axis: .vertical)
                .lineLimit(2...5)
                .font(.appBody)
                .padding(AppSpacing.md)
                .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AppCornerRadius.md)
                    .stroke(Color.appBorder.opacity(0.4), lineWidth: 0.5))
                .appWritingTools()
        }
    }

    // MARK: - Suggestion prompts

    private var suggestionPrompts: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Try asking")
                .font(.appCaption.bold())
                .foregroundStyle(Color.appTextMuted)
                .padding(.top, AppSpacing.sm)
            ForEach(suggestions, id: \.self) { prompt in
                Button {
                    question = prompt
                } label: {
                    HStack {
                        Image(systemName: "sparkle")
                            .foregroundStyle(Color.appPrimary)
                        Text(prompt)
                            .font(.appCaption)
                            .foregroundStyle(Color.appText)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(AppSpacing.sm)
                    .background(Color.appBGCard.opacity(0.5),
                                in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestions: [String] {
        if selectedDocuments.count >= 2 {
            return [
                "What's different between these documents?",
                "Summarize each in one sentence.",
                "What dates and amounts are mentioned?"
            ]
        }
        return [
            "Summarize this document.",
            "What are the key dates?",
            "What action items does it list?"
        ]
    }

    // MARK: - Answer card

    private func answerCard(_ answer: MultiDocQAService.Answer) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.appPrimary)
                Text(answer.usedFoundationModels ? "Apple Intelligence" : "Keyword fallback")
                    .font(.appMicro)
                    .foregroundStyle(Color.appTextMuted)
                Spacer()
            }

            Text(answer.text)
                .font(.appBody)
                .foregroundStyle(Color.appText)
                .textSelection(.enabled)

            if !answer.citations.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Sources")
                        .font(.appCaption.bold())
                        .foregroundStyle(Color.appTextMuted)
                    ForEach(answer.citations) { citation in
                        Button {
                            citationToOpen = citation
                        } label: {
                            HStack(alignment: .top, spacing: AppSpacing.sm) {
                                Image(systemName: "quote.opening")
                                    .foregroundStyle(Color.appAccent)
                                    .font(.system(size: 12))
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(citation.documentName)
                                        .font(.appCaption.bold())
                                        .foregroundStyle(Color.appAccent)
                                    Text(citation.snippet)
                                        .font(.appMicro)
                                        .foregroundStyle(Color.appTextMuted)
                                        .lineLimit(3)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(AppSpacing.sm)
                            .background(Color.appAccent.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
    }

    // MARK: - Action

    private func ask() async {
        let docs = selectedDocuments
        let q = question
        isWorking = true
        answer = nil
        let result = await MultiDocQAService.shared.answer(question: q, documents: docs)
        answer = result
        isWorking = false
        HapticManager.success()
    }
}

// MARK: - Multi-doc picker

private struct MultiDocPicker: View {
    let allDocs: [DocumentFile]
    @Binding var selected: Set<UUID>
    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""

    private var filtered: [DocumentFile] {
        guard !search.isEmpty else { return allDocs }
        let lower = search.lowercased()
        return allDocs.filter {
            $0.name.lowercased().contains(lower) ||
            $0.aiSuggestedName?.lowercased().contains(lower) == true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { doc in
                    Button {
                        if selected.contains(doc.id) {
                            selected.remove(doc.id)
                        } else {
                            selected.insert(doc.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: selected.contains(doc.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(doc.id) ? Color.appPrimary : Color.appTextDim)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.aiSuggestedName ?? doc.name)
                                    .font(.appBody)
                                    .foregroundStyle(Color.appText)
                                if let tag = doc.tag {
                                    Text(tag.rawValue)
                                        .font(.appMicro)
                                        .foregroundStyle(tag.color)
                                }
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Select documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Citation detail

private struct CitationDetailView: View {
    let citation: MultiDocQAService.Citation
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    private var matchedDocument: DocumentFile? {
        let id = citation.documentID
        let descriptor = FetchDescriptor<DocumentFile>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(citation.documentName)
                        .font(.appH3)
                        .foregroundStyle(Color.appText)

                    Text(citation.snippet)
                        .font(.appBody)
                        .foregroundStyle(Color.appText)
                        .padding(AppSpacing.md)
                        .background(Color.appAccent.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
                        .textSelection(.enabled)

                    if let doc = matchedDocument, let summary = doc.aiSummary {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("About this document")
                                .font(.appCaption.bold())
                                .foregroundStyle(Color.appTextMuted)
                            Text(summary)
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextMuted)
                        }
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(Color.appBGDark.ignoresSafeArea())
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
