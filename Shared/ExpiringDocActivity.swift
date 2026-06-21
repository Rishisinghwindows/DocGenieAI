//
//  ExpiringDocActivity.swift
//  Shared (compiled into both the main app target AND DocSageWidgetExtension)
//
//  Role: ActivityAttributes contract for the "expiring document" Live
//  Activity. ActivityKit requires that the EXACT same struct type — same
//  module, same fields — be present in both the app process (which starts/
//  updates/ends activities) and the widget process (which renders them).
//
//  We satisfy this by living in a `Shared/` source directory that's added
//  to both targets in project.yml. The struct is `public` to allow that
//  cross-target visibility.
//
//  Fields are split into two groups per ActivityKit's design:
//    • Top-level `ExpiringDocAttributes` — immutable identity (which doc,
//      what kind of doc, what icon). Set once when the activity starts.
//    • `ContentState` — mutable per-update state (days remaining, expiry
//      date). Refreshed daily by ExpiryActivityService.reconcile.
//
//  Why init is explicit: ActivityAttributes is Codable & Hashable, and
//  the synthesized memberwise init is internal by default. We expose an
//  explicit public init so callers in either target can construct it.
//

import ActivityKit
import Foundation

public struct ExpiringDocAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var daysRemaining: Int
        public var expiryDate: Date

        public init(daysRemaining: Int, expiryDate: Date) {
            self.daysRemaining = daysRemaining
            self.expiryDate = expiryDate
        }
    }

    public var documentID: String
    public var documentName: String
    public var documentType: String   // "Passport", "Insurance Card", "License", or freeform tag
    public var iconSystemName: String

    public init(documentID: String, documentName: String, documentType: String, iconSystemName: String) {
        self.documentID = documentID
        self.documentName = documentName
        self.documentType = documentType
        self.iconSystemName = iconSystemName
    }
}
