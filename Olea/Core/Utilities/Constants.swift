import Foundation
import UniformTypeIdentifiers

enum AppConstants {
    static let appDocumentsSubdirectory = "DocGenieFiles"

    static let supportedExtensions: Set<String> = [
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "txt", "csv", "xml", "rtf",
        "jpg", "jpeg", "png", "heic", "webp", "bmp", "gif", "tiff"
    ]

    static let supportedUTTypes: [UTType] = [
        .pdf, .presentation, .spreadsheet, .plainText,
        .commaSeparatedText, .xml, .rtf, .image,
        .jpeg, .png, .heic, .webP, .bmp, .gif, .tiff,
        UTType("com.microsoft.word.doc") ?? .data,
        UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
        UTType("com.microsoft.excel.xls") ?? .data,
        UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data,
        UTType("com.microsoft.powerpoint.ppt") ?? .data,
        UTType("org.openxmlformats.presentationml.presentation") ?? .data,
    ]

    static let maxFileSizeBytes: Int64 = 500 * 1024 * 1024 // 500 MB
    static let appName = "Olea"
    static let supportEmail = "support@olea.app"
    static let appStoreURL = "https://apps.apple.com/app/olea/id0000000000"
}

// MARK: - Usage Limits & Pro Gating
//
// UsageManager owns three orthogonal concerns:
//   1. **Tier state** — free vs. Pro, persisted in UserDefaults.
//   2. **Daily quotas** — tool uses, conversations, voice notes, pipelines.
//      Free tier hits a wall; Pro is unlimited.
//   3. **Ads orchestration** — `trackToolUse()` is the single central hook
//      that increments the daily counter AND triggers the frequency-capped
//      interstitial via `AdsCoordinator.recordToolCompletion()`. View models
//      call `trackToolUse()` from every successful tool path; the ads layer
//      is invisible to them.
//
// Pro state mirrors into AdsCoordinator via `syncAdsProState()` — called
// from App.init, upgradeToPro, and restorePurchase so that Pro users see
// no ads from the first frame, no relaunch required.

@MainActor
@Observable
final class UsageManager {
    static let shared = UsageManager()

    // MARK: - Tier

    enum Tier: String {
        case free
        case pro
    }

    var currentTier: Tier {
        UserDefaults.standard.bool(forKey: "isProUser") ? .pro : .free
    }

    // MARK: - Free Tier Limits

    struct FreeLimits {
        static let toolUsesPerDay = 5
        static let conversationsPerDay = 3
        static let voiceNotesPerDay = 2
        static let memoriesMax = 5
        static let pipelinesPerDay = 1
        static let maxFileSize: Int64 = 50 * 1024 * 1024 // 50 MB
    }

    // MARK: - Daily Usage Tracking

    private let toolUsesKey = "dailyToolUses"
    private let conversationsKey = "dailyConversations"
    private let voiceNotesKey = "dailyVoiceNotes"
    private let pipelinesKey = "dailyPipelines"
    private let lastResetKey = "lastDailyReset"

    private var toolUsesToday: Int {
        get { getDailyCount(toolUsesKey) }
        set { setDailyCount(toolUsesKey, value: newValue) }
    }

    private var conversationsToday: Int {
        get { getDailyCount(conversationsKey) }
        set { setDailyCount(conversationsKey, value: newValue) }
    }

    private var voiceNotesToday: Int {
        get { getDailyCount(voiceNotesKey) }
        set { setDailyCount(voiceNotesKey, value: newValue) }
    }

    private var pipelinesToday: Int {
        get { getDailyCount(pipelinesKey) }
        set { setDailyCount(pipelinesKey, value: newValue) }
    }

    private init() {
        resetIfNewDay()
    }

    // MARK: - Check & Track

    func canUseTool() -> Bool {
        if currentTier == .pro { return true }
        resetIfNewDay()
        return toolUsesToday < FreeLimits.toolUsesPerDay
    }

    func canStartConversation() -> Bool {
        if currentTier == .pro { return true }
        resetIfNewDay()
        return conversationsToday < FreeLimits.conversationsPerDay
    }

    func canRecordVoiceNote() -> Bool {
        if currentTier == .pro { return true }
        resetIfNewDay()
        return voiceNotesToday < FreeLimits.voiceNotesPerDay
    }

    func canRunPipeline() -> Bool {
        if currentTier == .pro { return true }
        resetIfNewDay()
        return pipelinesToday < FreeLimits.pipelinesPerDay
    }

    func canSaveMemory(currentCount: Int) -> Bool {
        if currentTier == .pro { return true }
        return currentCount < FreeLimits.memoriesMax
    }

    func canImportFile(size: Int64) -> Bool {
        if currentTier == .pro { return size <= AppConstants.maxFileSizeBytes }
        return size <= FreeLimits.maxFileSize
    }

    /// Single tracking entry-point. Increments the daily counter AND notifies
    /// the AdsCoordinator so a frequency-capped interstitial may fire. Call
    /// this from every tool's success path (after the file is written +
    /// HapticManager.success()).
    func trackToolUse() {
        toolUsesToday += 1
        AdsCoordinator.shared.recordToolCompletion()
    }
    func trackConversation() { conversationsToday += 1 }
    func trackVoiceNote() { voiceNotesToday += 1 }
    func trackPipeline() {
        pipelinesToday += 1
        AdsCoordinator.shared.recordToolCompletion()
    }

    // MARK: - Remaining

    var remainingTools: Int {
        currentTier == .pro ? .max : max(0, FreeLimits.toolUsesPerDay - toolUsesToday)
    }

    var remainingConversations: Int {
        currentTier == .pro ? .max : max(0, FreeLimits.conversationsPerDay - conversationsToday)
    }

    var limitMessage: String {
        if currentTier == .pro { return "" }
        return "\(remainingTools) tools left today"
    }

    var isPro: Bool { currentTier == .pro }

    // MARK: - Upgrade

    /// Sync the Ads coordinator's Pro flag from the persisted tier. Call this
    /// from App.init and after any tier change so banner/interstitial/app-open
    /// surfaces no-op for Pro users instantly.
    func syncAdsProState() {
        AdsCoordinator.shared.isProUser = isPro
    }

    func upgradeToPro() {
        UserDefaults.standard.set(true, forKey: "isProUser")
        syncAdsProState()
    }

    func restorePurchase() {
        // In production: verify with StoreKit 2
        UserDefaults.standard.set(true, forKey: "isProUser")
        syncAdsProState()
    }

    // MARK: - Daily Reset

    private func resetIfNewDay() {
        let lastReset = UserDefaults.standard.object(forKey: lastResetKey) as? Date ?? .distantPast
        if !Calendar.current.isDateInToday(lastReset) {
            UserDefaults.standard.set(0, forKey: toolUsesKey)
            UserDefaults.standard.set(0, forKey: conversationsKey)
            UserDefaults.standard.set(0, forKey: voiceNotesKey)
            UserDefaults.standard.set(0, forKey: pipelinesKey)
            UserDefaults.standard.set(Date(), forKey: lastResetKey)
        }
    }

    private func getDailyCount(_ key: String) -> Int {
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: key)
    }

    private func setDailyCount(_ key: String, value: Int) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
