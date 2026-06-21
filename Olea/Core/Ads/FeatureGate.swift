//
//  FeatureGate.swift
//  Olea
//
//  Role: Per-feature usage tracker that decides when to show a rewarded ad.
//
//  Policy:
//    • The user's FIRST tap on any tool is free — record but don't gate.
//    • Every subsequent tap on the same tool requires a rewarded ad.
//    • Pro users skip the gate entirely.
//    • The counter is persisted in UserDefaults so the rule survives launches.
//
//  Why per-tool (not per-app): users build trust with each tool by trying it
//  once. Forcing an ad on a tool they've never used would feel like a paywall.
//  Once they know what a tool does, the rewarded ad becomes a fair trade.
//
//  Why UserDefaults (not SwiftData): the data is tiny (one Int per tool ID),
//  lifecycle-independent of SwiftData migrations, and read on every tap — so
//  the lighter store wins.
//

import Foundation

@MainActor
final class FeatureGate {
    static let shared = FeatureGate()
    private init() {}

    private static let keyPrefix = "featureGate.useCount."

    // MARK: - Public API

    /// Returns the next action the UI should take for a given tool.
    func evaluate(toolID: String) -> Decision {
        // Pro users bypass entirely.
        if UsageManager.shared.isPro { return .openFree }

        // Ads are off entirely → don't gate; the app is effectively free-no-ads.
        if !AdsConfig.isEnabled { return .openFree }

        // No consent / GDPR denied → can't request ads, so don't gate.
        if !AdConsentManager.shared.canRequestAds { return .openFree }

        let count = usageCount(toolID: toolID)
        if count == 0 {
            return .openFree
        } else {
            return .needsRewardedAd
        }
    }

    /// Increment the usage counter for this tool. Call AFTER the feature
    /// actually opened (i.e. after a free open OR after a successful reward).
    func recordUse(toolID: String) {
        let next = usageCount(toolID: toolID) + 1
        UserDefaults.standard.set(next, forKey: Self.keyPrefix + toolID)
        AppLogger.ui.info("FeatureGate recorded use #\(next, privacy: .public) for tool: \(toolID, privacy: .public)")
    }

    /// Current usage count for a tool (mostly for UI / debugging).
    func usageCount(toolID: String) -> Int {
        UserDefaults.standard.integer(forKey: Self.keyPrefix + toolID)
    }

    /// Wipe the entire gate state. Used when the user unlocks Pro (so Pro→
    /// free downgrade doesn't carry stale counts) and from the dev-only
    /// "Reset gates" debug action.
    func resetAll() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Decision

    enum Decision {
        /// Open the tool immediately — no ad required.
        case openFree
        /// Present the rewarded-ad gate UI. If the user watches the ad
        /// successfully, then open the tool.
        case needsRewardedAd
    }
}
