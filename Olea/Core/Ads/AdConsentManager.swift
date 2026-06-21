//
//  AdConsentManager.swift
//  DocGenieAI
//
//  Role: Manages the two-stage consent funnel required by Apple + GDPR/CPRA
//  before AdMob can serve ads to the user.
//
//  Stage 1 — UMP (Google's User Messaging Platform):
//    Collects GDPR / CPRA consent for EU + California users via a Google-
//    managed form. Required by AdMob policy globally; without it, Google may
//    refuse to serve ads in regulated regions and the AdMob account can be
//    flagged for non-compliance. For users outside regulated regions the
//    form silently no-ops.
//
//  Stage 2 — ATT (App Tracking Transparency):
//    Apple-required prompt for IDFA access (iOS 14+). Without ATT grant,
//    AdMob serves non-personalized ads only — earning ~30–50% less revenue
//    but staying legally compliant.
//
//  Ordering: UMP MUST come before ATT. Apple forces ATT to be the last
//  tracking-related prompt the app shows, and UMP's form can itself reference
//  the ATT decision. Reversing the order will make AdMob's compliance checks
//  see an inconsistent state.
//
//  Usage:
//    Call `requestConsentIfNeeded(from:)` from `DocGenieAIApp.task` after
//    onboarding completes, before any ad is shown. The method is idempotent —
//    it short-circuits via `hasCompletedConsentFlow` on subsequent calls.
//

import Foundation
import UIKit
import AppTrackingTransparency
import AdSupport
import UserMessagingPlatform
@MainActor
final class AdConsentManager {
    static let shared = AdConsentManager()
    private init() {}

    /// True once both stages have completed (granted, denied, or "not required"
    /// for users outside GDPR/CPRA regions).
    private(set) var hasCompletedConsentFlow: Bool = false

    /// Whether the user granted IDFA tracking via ATT.
    var hasTrackingAuthorization: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    /// Whether Google's UMP says we can request personalized ads.
    var canRequestPersonalizedAds: Bool {
        UMPConsentInformation.sharedInstance.canRequestAds
            && hasTrackingAuthorization
    }

    /// Whether Google's UMP says we can request ANY ads (personalized or not).
    var canRequestAds: Bool {
        UMPConsentInformation.sharedInstance.canRequestAds
    }

    /// Drive the full consent funnel: UMP first (so we know if the user is in
    /// scope of GDPR / CPRA), then ATT. iOS forces ATT to be the LAST tracking
    /// prompt the app shows, so this ordering matters.
    func requestConsentIfNeeded(from viewController: UIViewController) async {
        guard !hasCompletedConsentFlow else { return }
        await requestUMPConsent(from: viewController)
        await requestATT()
        hasCompletedConsentFlow = true
        AppLogger.ui.info("Consent flow complete. ATT: \(self.hasTrackingAuthorization, privacy: .public), UMP canRequest: \(self.canRequestAds, privacy: .public)")
    }

    /// Re-show the privacy options form (e.g. from a "Manage ad preferences"
    /// row in Settings). Required by GDPR for users to withdraw consent.
    func presentPrivacyOptionsForm(from viewController: UIViewController) async throws {
        try await UMPConsentForm.presentPrivacyOptionsForm(from: viewController)
    }

    // MARK: - Internal

    private func requestUMPConsent(from viewController: UIViewController) async {
        let parameters = UMPRequestParameters()
        // Treat as production unless you toggle for testing — UMP debug mode
        // is only useful when testing against the test geographies.
        parameters.tagForUnderAgeOfConsent = false

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { error in
                    if let error { cont.resume(throwing: error) } else { cont.resume() }
                }
            }
        } catch {
            AppLogger.ui.error("UMP consent info update failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Load & present the consent form if required (EU/UK/CA users).
        do {
            try await UMPConsentForm.loadAndPresentIfRequired(from: viewController)
        } catch {
            AppLogger.ui.error("UMP form present failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func requestATT() async {
        // Skip if we already have a determined status — iOS won't show the
        // prompt twice anyway, but this avoids the unnecessary system call.
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else { return }

        let granted = await ATTrackingManager.requestTrackingAuthorization()
        AppLogger.ui.info("ATT result: \(String(describing: granted), privacy: .public)")
    }
}

private extension ATTrackingManager {
    /// async/await wrapper around requestTrackingAuthorization.
    static func requestTrackingAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        await withCheckedContinuation { cont in
            ATTrackingManager.requestTrackingAuthorization { status in
                cont.resume(returning: status)
            }
        }
    }
}
