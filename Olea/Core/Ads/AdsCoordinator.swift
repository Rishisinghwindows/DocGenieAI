//
//  AdsCoordinator.swift
//  DocGenieAI
//
//  Role: Single owner of the AdMob ad lifecycle. Everything else in the app
//  talks to this class; nobody else holds GADAppOpenAd / GADInterstitialAd
//  references directly. This keeps frequency caps, Pro-state gating, and
//  consent enforcement in one auditable place.
//
//  Lifecycle hooks (call sites are intentionally few):
//    • `start()`                    — once, from `DocGenieAIApp.init()`
//    • `onAppLaunched()`            — once per cold launch, from the
//                                      WindowGroup `.task` after consent
//    • `onAppEnteredForeground()`   — `scenePhase` change to `.active`
//    • `onAppEnteredBackground()`   — `scenePhase` change to `.background`
//    • `recordToolCompletion()`     — every successful tool use; the central
//                                      hook is `UsageManager.trackToolUse()`
//                                      so every tool feeds this automatically
//
//  Concurrency: @preconcurrency on the import because Google's SDK is not yet
//  Sendable-annotated under Swift 6 strict mode. The non-Sendable ad objects
//  are ferried across the DispatchQueue.main hop via `AdLoadResult` — see
//  the rationale on that wrapper at the bottom of the file.
//
//  Gating: see `shouldShowAds`. Ads no-op silently when (a) ads are disabled
//  via `AdsConfig.isEnabled`, (b) the user is Pro, or (c) UMP says we can't
//  request ads (e.g., GDPR consent denied in EU).
//

import Foundation
import UIKit
import SwiftUI
@preconcurrency import GoogleMobileAds

@MainActor
final class AdsCoordinator: NSObject, ObservableObject {
    static let shared = AdsCoordinator()

    private override init() {
        super.init()
    }

    // MARK: - Public flags

    /// Set to true once the user is Pro / subscription is active. All ad calls
    /// no-op while true. Wire from your existing UsageManager / StoreKit flow.
    @Published var isProUser: Bool = false

    // MARK: - Internal state

    private var appOpenAd: GADAppOpenAd?
    private var interstitialAd: GADInterstitialAd?
    private var rewardedAd: GADRewardedAd?
    private var appOpenLoadedAt: Date?
    private var interstitialLoadedAt: Date?
    private var lastInterstitialShownAt: Date?
    private var lastBackgroundedAt: Date?
    private var toolCompletionCount: Int = 0
    private var hasStarted: Bool = false

    /// Callback for the in-flight rewarded ad. Set by `showRewarded(...)`,
    /// fired by `userDidEarnReward` (success) or `adDidDismissFullScreen`
    /// without a prior reward (user closed it early — no callback fires).
    private var pendingRewardCallback: (() -> Void)?

    @AppStorage("ads_launch_count") private var launchCount: Int = 0

    // MARK: - Public API

    /// Initialize the SDK. Idempotent — safe to call from app launch.
    func start() {
        guard AdsConfig.isEnabled, !hasStarted else { return }
        hasStarted = true

        // Register dev devices so real ad units render with "Test Ad" labels.
        // On first launch with no IDs filled in, the SDK logs a line like:
        //   "To get test ads on this device, set: GADMobileAds.sharedInstance()
        //    .requestConfiguration.testDeviceIdentifiers = @[ @"33BE2250..." ]"
        // Copy that hex string into AdsTestDevices.identifiers and rebuild.
        // Once added, you'll see real production inventory marked "Test Ad" —
        // safe to tap, no AdMob policy violations.
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = AdsTestDevices.identifiers

        GADMobileAds.sharedInstance().start { _ in
            AppLogger.ui.info("AdMob SDK started.")
            Task { @MainActor in
                self.preloadAppOpen()
                self.preloadInterstitial()
                self.preloadRewarded()
            }
        }
    }

    func onAppEnteredForeground() {
        guard shouldShowAds else { return }
        guard let backgrounded = lastBackgroundedAt else { return }
        let interval = Date().timeIntervalSince(backgrounded)
        guard interval >= AdsConfig.appOpenMinBackgroundInterval else { return }
        showAppOpenIfReady()
    }

    func onAppEnteredBackground() {
        lastBackgroundedAt = Date()
    }

    func onAppLaunched() {
        launchCount += 1
        guard shouldShowAds else { return }
        guard launchCount >= AdsConfig.appOpenMinLaunchCount else { return }
        showAppOpenIfReady()
    }

    /// Record a tool completion. Every Nth one triggers an interstitial.
    func recordToolCompletion() {
        guard shouldShowAds else { return }
        toolCompletionCount += 1
        if toolCompletionCount % AdsConfig.interstitialEveryNToolCompletions == 0 {
            showInterstitialIfReady()
        }
    }

    var shouldShowAds: Bool {
        AdsConfig.isEnabled
            && !isProUser
            && AdConsentManager.shared.canRequestAds
    }

    // MARK: - App Open

    private func preloadAppOpen() {
        guard AdsConfig.isEnabled, appOpenAd == nil else { return }
        guard !AdsConfig.isPlaceholder(AdsConfig.UnitID.appOpen) else { return }
        GADAppOpenAd.load(withAdUnitID: AdsConfig.UnitID.appOpen, request: GADRequest()) { [weak self] ad, error in
            // The load callback runs off-main but Google's SDK guarantees its
            // ad object can be safely retained here. Capture into a Sendable
            // wrapper to satisfy strict concurrency, then hop to MainActor.
            let box = AdLoadResult<GADAppOpenAd>(ad: ad, errorDescription: error?.localizedDescription)
            DispatchQueue.main.async {
                guard let self else { return }
                if let err = box.errorDescription {
                    AppLogger.ui.error("App-open ad load failed: \(err, privacy: .public)")
                    return
                }
                self.appOpenAd = box.ad
                self.appOpenLoadedAt = Date()
                box.ad?.fullScreenContentDelegate = self
            }
        }
    }

    private func showAppOpenIfReady() {
        guard let ad = appOpenAd, isAppOpenFresh else {
            appOpenAd = nil
            preloadAppOpen()
            return
        }
        guard let rootVC = Self.topViewController() else { return }
        ad.present(fromRootViewController: rootVC)
    }

    private var isAppOpenFresh: Bool {
        guard let loadedAt = appOpenLoadedAt else { return false }
        return Date().timeIntervalSince(loadedAt) < 4 * 60 * 60
    }

    // MARK: - Interstitial

    private func preloadInterstitial() {
        guard AdsConfig.isEnabled, interstitialAd == nil else { return }
        guard !AdsConfig.isPlaceholder(AdsConfig.UnitID.interstitial) else { return }
        GADInterstitialAd.load(withAdUnitID: AdsConfig.UnitID.interstitial, request: GADRequest()) { [weak self] ad, error in
            let box = AdLoadResult<GADInterstitialAd>(ad: ad, errorDescription: error?.localizedDescription)
            DispatchQueue.main.async {
                guard let self else { return }
                if let err = box.errorDescription {
                    AppLogger.ui.error("Interstitial ad load failed: \(err, privacy: .public)")
                    return
                }
                self.interstitialAd = box.ad
                self.interstitialLoadedAt = Date()
                box.ad?.fullScreenContentDelegate = self
            }
        }
    }

    // MARK: - Rewarded

    /// Whether a rewarded ad is loaded and ready to show right now. Use this
    /// to decide between "show ad gate" vs. "fall open (ad not available)".
    var isRewardedReady: Bool { rewardedAd != nil }

    /// Show a rewarded ad. `onReward` fires only if the user finishes the ad
    /// AND earns the reward. If the ad fails to load or the user dismisses
    /// early, `onReward` does NOT fire — caller should provide its own UX
    /// (typically: a small banner saying "ad unavailable, try again later").
    ///
    /// Fall-open recommendation: if `isRewardedReady == false`, just unlock
    /// the feature anyway. Better to give the user the feature than block them
    /// on ad-network issues.
    func showRewarded(from viewController: UIViewController, onReward: @escaping () -> Void) {
        guard let ad = rewardedAd else {
            AppLogger.ui.error("Rewarded ad not ready; preloading for next time.")
            preloadRewarded()
            return
        }
        pendingRewardCallback = onReward
        ad.present(fromRootViewController: viewController) { [weak self] in
            // The user earned the reward — invoke the callback exactly once.
            guard let self else { return }
            let cb = self.pendingRewardCallback
            self.pendingRewardCallback = nil
            cb?()
        }
    }

    private func preloadRewarded() {
        guard AdsConfig.isEnabled, rewardedAd == nil else { return }
        guard !AdsConfig.isPlaceholder(AdsConfig.UnitID.rewarded) else { return }
        GADRewardedAd.load(withAdUnitID: AdsConfig.UnitID.rewarded, request: GADRequest()) { [weak self] ad, error in
            let box = AdLoadResult<GADRewardedAd>(ad: ad, errorDescription: error?.localizedDescription)
            DispatchQueue.main.async {
                guard let self else { return }
                if let err = box.errorDescription {
                    AppLogger.ui.error("Rewarded ad load failed: \(err, privacy: .public)")
                    return
                }
                self.rewardedAd = box.ad
                box.ad?.fullScreenContentDelegate = self
            }
        }
    }

    private func showInterstitialIfReady() {
        guard let ad = interstitialAd else {
            preloadInterstitial()
            return
        }
        if let last = lastInterstitialShownAt,
           Date().timeIntervalSince(last) < AdsConfig.interstitialMinInterval {
            return
        }
        guard let rootVC = Self.topViewController() else { return }
        ad.present(fromRootViewController: rootVC)
        lastInterstitialShownAt = Date()
    }

    // MARK: - Top-most VC helper

    private static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
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

// MARK: - Load-result box
//
// Google's load callbacks receive non-Sendable ad objects. Swift 6 strict
// concurrency won't allow them across actor boundaries via normal `Task {}`
// hops. Wrapping in this @unchecked-Sendable box and using DispatchQueue.main
// is the SDK's documented workaround until they ship Sendable conformance.
private final class AdLoadResult<T: AnyObject>: @unchecked Sendable {
    let ad: T?
    let errorDescription: String?
    init(ad: T?, errorDescription: String?) {
        self.ad = ad
        self.errorDescription = errorDescription
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdsCoordinator: @preconcurrency GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        AppLogger.ui.error("Ad failed to present: \(error.localizedDescription, privacy: .public)")
        if ad is GADAppOpenAd { appOpenAd = nil; preloadAppOpen() }
        if ad is GADInterstitialAd { interstitialAd = nil; preloadInterstitial() }
        if ad is GADRewardedAd {
            rewardedAd = nil
            preloadRewarded()
            // Reward callback never fired — clear it so it can't accidentally
            // run on a later, unrelated ad.
            pendingRewardCallback = nil
        }
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if ad is GADAppOpenAd { appOpenAd = nil; preloadAppOpen() }
        if ad is GADInterstitialAd { interstitialAd = nil; preloadInterstitial() }
        if ad is GADRewardedAd {
            rewardedAd = nil
            preloadRewarded()
            // If pendingRewardCallback is still set here, the user closed the
            // ad before earning the reward — drop the callback silently.
            pendingRewardCallback = nil
        }
    }
}
