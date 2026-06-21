//
//  OnboardingView.swift
//  DocGenieAI
//
//  Role: First-launch experience. Replaces the previous 3-page slideshow
//  with a single page + single CTA. The product story collapses to one
//  promise:
//
//      "Your documents, automatically organized."
//
//  Why single-page: every Apple Design Awards-grade app has converged on
//  short, single-CTA onboarding (Granola, Linear, Things, Bear). The 3-page
//  swipe pattern feels 2019-era and bounces users; one bold page with a
//  clear value prop converts better and gets users to the magic moment
//  (their first auto-organized scan) sooner.
//
//  Visual composition (top to bottom):
//    • AnimatedMeshBackground vignette  — living-canvas backdrop
//    • Hero tray icon                     — glass disk + AI shimmer rim +
//                                            breathing symbol effect
//    • H1 headline + body                 — staggered phase animation
//    • Three-bullet row                   — "Auto-named / Find anything /
//                                            On device"
//    • PrimaryButton "Get started"        — the only action on the page
//    • Honest tagline                     — "No accounts. Documents stay on
//                                            your device. Free with ads."
//
//  Phase animation: a private `phase: Int` drives staggered reveals (0 →
//  headline, 1 → body+bullets, 2 → CTA) with spring transitions, so users
//  perceive the content as composing in front of them rather than appearing
//  all at once.
//

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var appeared = false
    @State private var phase: Int = 0  // 0 = headline, 1 = body+bullets, 2 = CTA

    var body: some View {
        ZStack {
            // Living-canvas backdrop. On iOS 18+ this is a real mesh gradient
            // with drifting control points; iOS 17 gets a slow angular sweep.
            AnimatedMeshBackground()
                .ignoresSafeArea()
                .opacity(0.55)
                .overlay(Color.appBGDark.opacity(0.55).ignoresSafeArea())

            // Subtle radial vignette so content reads on any device tone.
            RadialGradient(
                colors: [.clear, Color.appBGDark.opacity(0.55)],
                center: .center,
                startRadius: 200,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                heroIcon

                Spacer().frame(height: AppSpacing.xl)

                VStack(spacing: AppSpacing.md) {
                    Text("Your documents,\nautomatically organized.")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .kerning(-0.4)
                        .foregroundStyle(Color.appText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                        .opacity(phase >= 0 ? 1 : 0)
                        .offset(y: phase >= 0 ? 0 : 16)

                    Text("Scan, import, or share a document. Olea names it, tags it, summarizes it — entirely on your device.")
                        .font(.appBody)
                        .foregroundStyle(Color.appTextMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, AppSpacing.xl)
                        .opacity(phase >= 1 ? 1 : 0)
                        .offset(y: phase >= 1 ? 0 : 16)
                }

                Spacer().frame(height: AppSpacing.lg)

                bulletRow
                    .opacity(phase >= 1 ? 1 : 0)
                    .offset(y: phase >= 1 ? 0 : 16)

                Spacer()

                PrimaryButton(title: "Get started") {
                    HapticManager.medium()
                    onComplete()
                }
                .padding(.horizontal, AppSpacing.xl)
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? 0 : 12)

                Text("No accounts. Documents stay on your device. Free with ads.")
                    .font(.appMicro)
                    .foregroundStyle(Color.appTextDim)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xxl)
                    .opacity(phase >= 2 ? 1 : 0)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                phase = 0
                appeared = true
            }
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { phase = 1 }
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { phase = 2 }
        }
    }

    // MARK: - Hero icon
    //
    // Tray icon under a soft halo, wrapped in the iridescent AI rim and breathing
    // via .symbolEffect(.breathe). This single composition is the brand mark of
    // the auto-inbox wedge.

    private var heroIcon: some View {
        ZStack {
            // Outer halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appPrimary.opacity(0.30), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .blur(radius: 20)

            // Glass disk
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 144, height: 144)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                )

            Image(systemName: "tray.full.fill")
                .font(.system(size: 58, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.appPrimary, Color.appAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .applyBreathingEffect()
        }
        .aiShimmerRim(cornerRadius: 90, lineWidth: 1.8)
        .scaleEffect(appeared ? 1.0 : 0.86)
        .opacity(appeared ? 1.0 : 0.0)
    }

    // MARK: - Three-bullet row

    private var bulletRow: some View {
        HStack(spacing: AppSpacing.md) {
            bullet(icon: "sparkles", title: "Auto-named", subtitle: "Smart filenames")
            bullet(icon: "magnifyingglass", title: "Find anything", subtitle: "By any phrase")
            bullet(icon: "shield.fill", title: "On device", subtitle: "Stays private")
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    private func bullet(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.appPrimary)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
            Text(title)
                .font(.appMicro.bold())
                .foregroundStyle(Color.appText)
            Text(subtitle)
                .font(.appMicro)
                .foregroundStyle(Color.appTextDim)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension View {
    /// .symbolEffect(.breathe) is iOS 18+; falls back to .pulse on iOS 17.
    @ViewBuilder
    func applyBreathingEffect() -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.breathe.plain.byLayer, options: .repeating)
        } else {
            self.symbolEffect(.pulse, options: .repeating)
        }
    }
}
