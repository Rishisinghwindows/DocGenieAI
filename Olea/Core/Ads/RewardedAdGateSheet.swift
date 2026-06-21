//
//  RewardedAdGateSheet.swift
//  Olea
//
//  Role: Premium sheet shown when a tool is gated by FeatureGate. Offers two
//  paths to unlock — "Watch a short ad" or "Upgrade to Pro" — plus a Cancel.
//
//  Design uses the same vocabulary as the rest of the app:
//    • Mesh-gradient backdrop
//    • Glass medallion with iridescent AI rim around the tool icon
//    • Spring entry animation
//    • Indigo→pink gradient on the primary CTA
//
//  Behavior:
//    • Tap "Watch ad" → AdsCoordinator.showRewarded. On reward, calls
//      onUnlock() which the caller uses to actually open the tool.
//    • Tap "Cancel" or swipe down → calls onCancel().
//    • If ad isn't loaded yet → fall open (call onUnlock immediately) so
//      users are never blocked by ad-network failures.
//

import SwiftUI

struct RewardedAdGateSheet: View {
    let toolName: String
    let toolIcon: String
    let onUnlock: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAd: Bool = false

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: AppSpacing.lg) {
                Spacer()
                heroMedallion
                copyBlock
                Spacer()
                ctaStack
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
        .interactiveDismissDisabled(isShowingAd)
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            Color.appBGDark.opacity(0.55).ignoresSafeArea()
            AnimatedMeshBackground()
                .opacity(0.20)
                .ignoresSafeArea()
                .frame(maxHeight: 320, alignment: .top)
        }
    }

    // MARK: - Hero medallion

    private var heroMedallion: some View {
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

            Image(systemName: toolIcon)
                .font(.system(size: 50, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: [Color.appPrimary, Color.appAccent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
        }
        .aiShimmerRim(cornerRadius: 80, lineWidth: 1.6)
    }

    // MARK: - Copy

    private var copyBlock: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Watch a short ad to use \(toolName)")
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.appText)
                .padding(.horizontal, AppSpacing.lg)
            Text("Olea is free thanks to short ads. Your first use of every tool is on the house — after that, a quick ad keeps the lights on.")
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - CTAs

    private var ctaStack: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                HapticManager.medium()
                presentAd()
            } label: {
                HStack {
                    if isShowingAd {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "play.rectangle.fill")
                    }
                    Text(isShowingAd ? "Loading…" : "Watch ad to use \(toolName)")
                        .font(.appBody.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(colors: [Color.appPrimary, Color.appAccent],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: AppCornerRadius.md)
                )
            }
            .buttonStyle(.plain)
            .disabled(isShowingAd)

            Button {
                HapticManager.light()
                onCancel()
            } label: {
                Text("Not now")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .disabled(isShowingAd)
        }
    }

    // MARK: - Ad presentation

    /// Asks the AdsCoordinator to present a rewarded ad. On successful reward,
    /// calls onUnlock(). If the ad isn't loaded, falls open (calls onUnlock
    /// anyway) rather than blocking the user on ad-network availability.
    private func presentAd() {
        // Find the root view controller to host the rewarded ad.
        guard let rootVC = Self.topViewController() else {
            // No host available — fall open.
            onUnlock()
            return
        }

        guard AdsCoordinator.shared.isRewardedReady else {
            // Ad not loaded yet. Fall open so the user is never blocked by
            // ad-network issues, and preload for next time.
            AppLogger.ui.info("Rewarded ad not ready at gate-present time; falling open.")
            onUnlock()
            return
        }

        isShowingAd = true
        AdsCoordinator.shared.showRewarded(from: rootVC) {
            // The user completed the ad and earned the reward.
            isShowingAd = false
            onUnlock()
        }
    }

    private static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: \.isKeyWindow)?.rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
