//
//  AskAboutRegionSheet.swift
//  DocGenieAI
//
//  Role: Bottom sheet for the PDF viewer's "Ask about this region" feature.
//  The user long-presses a region of a PDF page → the viewer hands us the
//  cropped UIImage → this sheet shows four intent buttons (Explain,
//  Translate, Define, Summarize) and the Foundation Models response.
//
//  Why a sheet vs. inline overlay: inline would compete with the user's
//  current scroll/zoom gesture state in the viewer; a sheet detaches the
//  conversation from the page state so the user can return to the same
//  scroll position when dismissed.
//
//  Backed by: VisualIntelligenceService (OCR's the region image, then asks
//  Foundation Models with intent-specific instructions). Falls back to a
//  leading-sentence preview on iOS <26.
//

import SwiftUI

struct AskAboutRegionSheet: View {
    let regionImage: UIImage

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIntent: VisualIntelligenceService.Intent?
    @State private var response: VisualIntelligenceService.Response?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    regionPreview

                    intentRow

                    if isWorking {
                        ProgressView("Reading the page…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.md)
                    }

                    if let response {
                        answerCard(response)
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(Color.appBGDark.ignoresSafeArea())
            .navigationTitle("Ask about this")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Region preview

    private var regionPreview: some View {
        Image(uiImage: regionImage)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.md)
                    .stroke(Color.appBorder, lineWidth: 0.5)
            )
    }

    // MARK: - Intent buttons

    private var intentRow: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(VisualIntelligenceService.Intent.allCases) { intent in
                Button {
                    Task { await run(intent) }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: intent.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(intent.label)
                            .font(.appMicro.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .foregroundStyle(selectedIntent == intent ? .white : Color.appText)
                    .background(
                        selectedIntent == intent
                            ? AnyShapeStyle(LinearGradient(colors: [Color.appPrimary, Color.appAccent],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color.appBGCard),
                        in: RoundedRectangle(cornerRadius: AppCornerRadius.md)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
            }
        }
    }

    // MARK: - Answer

    private func answerCard(_ response: VisualIntelligenceService.Response) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.appPrimary)
                Text(response.usedFoundationModels ? "Apple Intelligence" : "Basic mode")
                    .font(.appMicro)
                    .foregroundStyle(Color.appTextMuted)
                Spacer()
            }
            Text(response.text)
                .font(.appBody)
                .foregroundStyle(Color.appText)
                .textSelection(.enabled)

            if !response.sourceText.isEmpty {
                DisclosureGroup {
                    Text(response.sourceText)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextMuted)
                        .padding(.top, AppSpacing.xs)
                } label: {
                    Text("Source text")
                        .font(.appMicro.bold())
                        .foregroundStyle(Color.appTextMuted)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
    }

    private func run(_ intent: VisualIntelligenceService.Intent) async {
        selectedIntent = intent
        isWorking = true
        response = nil
        let result = await VisualIntelligenceService.shared.respond(to: intent, in: regionImage)
        response = result
        isWorking = false
        HapticManager.success()
    }
}
