import Foundation

/// Single source of truth for ad behavior. Swap test IDs → production IDs in one
/// place. Set `isEnabled = false` to completely disable AdMob (for example, if
/// you decide to return to the privacy-first positioning).
enum AdsConfig {

    /// Master kill switch. When false, no SDK calls happen, no banner renders,
    /// no interstitial loads. Use this for ad-free internal builds or to
    /// hot-disable in case AdMob policy changes break the integration.
    static let isEnabled: Bool = true

    // MARK: - Ad Unit IDs
    //
    // Google's documented TEST IDs ship by default so you can develop without
    // touching real inventory. Replace each with your production IDs from the
    // AdMob console BEFORE submitting to the App Store, or you'll get clicks
    // disabled and a policy strike.

    enum UnitID {
        static let appOpen     = isProduction ? productionAppOpen     : "ca-app-pub-3940256099942544/5575463023"
        static let banner      = isProduction ? productionBanner      : "ca-app-pub-3940256099942544/2934735716"
        static let interstitial = isProduction ? productionInterstitial : "ca-app-pub-3940256099942544/4411468910"
        /// Google's documented test ID for rewarded video ads.
        static let rewarded    = isProduction ? productionRewarded    : "ca-app-pub-3940256099942544/1712485313"
    }

    /// Returns true when an ad unit ID is still a placeholder (contains the
    /// sentinel `XXXX` we ship for slots that haven't been created in the
    /// AdMob console yet). Used by `AdsCoordinator` to skip the load entirely
    /// rather than handing a malformed ID to the SDK and logging an error on
    /// every retry.
    static func isPlaceholder(_ unitID: String) -> Bool {
        unitID.contains("XXXX")
    }

    // MARK: - Production IDs (placeholders — fill in)
    //
    // From AdMob console → Apps → DocSage → Ad units.

    // Production ad unit IDs. Created in AdMob console for Olea (app ID
    // ca-app-pub-6616355428134778~2771258288). Keep DEBUG builds on the
    // Google-supplied test IDs (declared above) so dev work doesn't tax real
    // inventory or trigger AdMob's invalid-traffic detection.
    //
    // STATUS: banner is live, the other three slots still need ad units
    // created in the AdMob console and pasted in here before release. Until
    // each is filled, the corresponding ad type silently no-ops in release
    // builds (better than serving a placeholder).
    private static let productionAppOpen      = "ca-app-pub-6616355428134778/9615338007"   // 2026-06-06
    private static let productionBanner       = "ca-app-pub-6616355428134778/9383248183"   // 2026-06-06
    private static let productionInterstitial = "ca-app-pub-XXXXXXXXXXXXXXXX/0000000002"  // TODO: create + paste
    private static let productionRewarded     = "ca-app-pub-6616355428134778/6757084841"   // 2026-06-06

    /// Always-on: every build (Debug + Release, simulator + device) uses the
    /// real AdMob unit IDs above. Your iPhone is whitelisted as an AdMob test
    /// device in `AdsCoordinator.start()`, so the SDK fetches real inventory
    /// but renders it labeled "Test Ad" — no policy strikes, no fraudulent
    /// clicks. See https://developers.google.com/admob/ios/test-ads#enable_test_devices.
    static let isProduction: Bool = true

    // MARK: - Frequency caps
    //
    // Show ads sparingly. Aggressive ads tank retention.

    /// Show an interstitial after this many "tool completion" events.
    /// 4 means the 4th, 8th, 12th, … tool action shows one.
    static let interstitialEveryNToolCompletions: Int = 4

    /// Don't show another interstitial within this interval, regardless of tool count.
    static let interstitialMinInterval: TimeInterval = 60

    /// Show the app open ad on cold launch only after this many launches.
    /// 2 means the second launch and beyond — first launch stays clean for
    /// onboarding.
    static let appOpenMinLaunchCount: Int = 2

    /// When the user backgrounds the app, require at least this much background
    /// time before showing the app open ad on next resume. Apple recommends
    /// >= 1 hour for backgrounded apps; 4h here is conservative.
    static let appOpenMinBackgroundInterval: TimeInterval = 4 * 60 * 60
}
