//
//  LocalizationManager.swift
//  Olea
//
//  Role: Live, mid-session language switching without a process restart.
//
//  Problem: setting `AppleLanguages` in UserDefaults only takes effect on the
//  next *cold* launch — and even then, only if the process actually terminates
//  rather than just resuming from background. Users who picked Spanish in the
//  Language card and tapped Inbox to confirm it changed saw English, because
//  the bundle's cached localization was loaded against the launch-time locale.
//
//  Fix (the standard iOS pattern, used by Telegram, Wire, and most i18n
//  helper libraries):
//    1. Subclass Bundle and override `localizedString(forKey:value:table:)`.
//    2. Use `object_setClass` to swap `Bundle.main` to the subclass once at
//       app start. Bundle.main keeps its identity — only its method dispatch
//       changes — so existing references stay valid.
//    3. Stash a "child" Bundle for the chosen locale's `.lproj` as an
//       associated object on Bundle.main. The override consults that child
//       whenever the user has chosen a non-system language.
//    4. Force SwiftUI to re-render by mutating an @Observable property; the
//       OleaApp root view binds `.id(currentLanguage ?? "system")` so a
//       language change throws the view tree away and rebuilds against the
//       newly-swapped bundle.
//
//  English source: when the user picks `en`, there's no `en.lproj` because
//  Xcode treats the source language strings as the keys themselves. We just
//  return `value ?? key` from the override, which is exactly what
//  `NSLocalizedString` and `String(localized:)` would emit for an unfound
//  key in the source language.
//
//  Follow-system: `currentLanguage == nil` skips the override path and lets
//  Bundle resolve as normal. If the user previously picked a specific
//  language and then switches back to system, we also remove the
//  `AppleLanguages` defaults entry so the next cold launch falls through
//  cleanly to iOS's preferred-language list.
//

import Foundation
import SwiftUI
import ObjectiveC.runtime

@MainActor
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    private static let storageKey = "oleaUserLanguageOverride"
    private static let appleLanguagesKey = "AppleLanguages"

    /// The user's chosen language code (e.g. `"es"`, `"fr"`, `"ar"`), or `nil`
    /// for "follow system locale". SwiftUI views that want to react to this
    /// (the root view's `.id(...)`) read it directly.
    private(set) var currentLanguage: String?

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        currentLanguage = (stored?.isEmpty == false) ? stored : nil
        Bundle.swapMainBundleClassIfNeeded()
        applyToBundle()
    }

    /// Switch the in-app language live. Pass `nil` (or `""`) to revert to
    /// follow-system. The change takes effect immediately for any view that
    /// re-renders after this call.
    func setLanguage(_ code: String?) {
        let normalized = (code?.isEmpty == false) ? code : nil
        currentLanguage = normalized
        let defaults = UserDefaults.standard
        if let normalized {
            defaults.set(normalized, forKey: Self.storageKey)
            // Mirror to AppleLanguages so a cold launch also respects the
            // choice (e.g. when iOS recreates the bundle from disk for an
            // extension or Live Activity).
            defaults.set([normalized], forKey: Self.appleLanguagesKey)
        } else {
            defaults.removeObject(forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        }
        applyToBundle()
    }

    private func applyToBundle() {
        if let lang = currentLanguage,
           let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            objc_setAssociatedObject(Bundle.main, &kOleaLocalizedBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else {
            // Either follow-system (nil) or English (no lproj — handled in
            // the override by returning value ?? key). Clear the override so
            // super.localizedString takes over for follow-system.
            objc_setAssociatedObject(Bundle.main, &kOleaLocalizedBundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - Bundle swizzle

private nonisolated(unsafe) var kOleaLocalizedBundleKey: UInt8 = 0

private final class OleaLocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        // English source: no en.lproj exists — Xcode treats keys themselves
        // as the English values. Short-circuit before consulting the
        // associated bundle.
        if let lang = currentLanguageSnapshot, lang == "en" {
            return value ?? key
        }
        if let bundle = objc_getAssociatedObject(self, &kOleaLocalizedBundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }

    /// Read the manager's current language without hopping onto the main
    /// actor — the swizzled lookup runs on whatever thread SwiftUI evaluates
    /// the view body on. The value is set on main but is a tiny String so
    /// the read race is harmless.
    private var currentLanguageSnapshot: String? {
        MainActor.assumeIsolated { LocalizationManager.shared.currentLanguage }
    }
}

extension Bundle {
    fileprivate static func swapMainBundleClassIfNeeded() {
        if object_getClass(Bundle.main) != OleaLocalizedBundle.self {
            object_setClass(Bundle.main, OleaLocalizedBundle.self)
        }
    }
}

/// Routes a string-key lookup through `Bundle.main.localizedString(...)` —
/// the swizzled method LocalizationManager installs at startup. Use this
/// instead of `String(localized:)` for *any* enum/struct computed property
/// that returns a localized String. `String(localized:)` goes through a
/// lower-level CFBundle path that ignores the runtime bundle swap, so a
/// user who flips from Arabic to Hindi keeps seeing Arabic for those
/// strings until the process restarts.
///
/// SwiftUI's `Text("…")` already goes through the swizzled path, so views
/// that pass string literals directly don't need this helper.
func oleaLocalized(_ key: String, comment: StaticString = "") -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}
