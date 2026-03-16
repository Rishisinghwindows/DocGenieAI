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
    static let appName = "DocSage"
    static let supportEmail = "support@docsage.app"
    static let appStoreURL = "https://apps.apple.com/app/docsage/id0000000000"
}

// MARK: - Usage Limits & Pro Gating

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

    func trackToolUse() { toolUsesToday += 1 }
    func trackConversation() { conversationsToday += 1 }
    func trackVoiceNote() { voiceNotesToday += 1 }
    func trackPipeline() { pipelinesToday += 1 }

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

    func upgradeToPro() {
        UserDefaults.standard.set(true, forKey: "isProUser")
    }

    func restorePurchase() {
        // In production: verify with StoreKit 2
        UserDefaults.standard.set(true, forKey: "isProUser")
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
