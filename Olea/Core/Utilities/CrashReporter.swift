//
//  CrashReporter.swift
//  DocGenieAI
//
//  Role: Field-crash visibility. MetricKit delivers aggregated crash, hang,
//  CPU-exception, and disk-write-exception diagnostics from the previous
//  launch the next time the app starts. This subscriber forwards each
//  payload into AppLogger so the same diagnostic shows up in:
//
//    • Console.app on a tethered Mac
//    • sysdiagnose archives users send to support
//    • Xcode Organizer's crash log view (via OSLog persistence)
//
//  Apple separately aggregates the same data in App Store Connect → Power
//  and Performance Metrics, but that pipeline is 24–48h delayed and
//  user-id-anonymized. Local OSLog gives us same-day visibility during beta.
//
//  Why @unchecked Sendable: NSObject + MXMetricManagerSubscriber is required
//  to be retained beyond static-let context (it's the subscriber, and
//  MetricKit holds onto it). The shared singleton is read-only after init,
//  so the unchecked annotation is sound; Apple's framework just doesn't
//  declare Sendable conformance yet.
//

import Foundation
import MetricKit

final class CrashReporter: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = CrashReporter()

    private override init() { super.init() }

    func start() {
        MXMetricManager.shared.add(self)
    }

    // MARK: - MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            AppLogger.ui.info("MetricKit metric payload: \(payload.jsonRepresentation(), privacy: .public)")
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            if let crashes = payload.crashDiagnostics, !crashes.isEmpty {
                for diag in crashes {
                    AppLogger.ui.fault("MetricKit crash: \(diag.jsonRepresentation(), privacy: .public)")
                }
            }
            if let hangs = payload.hangDiagnostics, !hangs.isEmpty {
                for diag in hangs {
                    AppLogger.ui.error("MetricKit hang: \(diag.jsonRepresentation(), privacy: .public)")
                }
            }
            if let cpuExceptions = payload.cpuExceptionDiagnostics, !cpuExceptions.isEmpty {
                for diag in cpuExceptions {
                    AppLogger.ui.error("MetricKit cpu exception: \(diag.jsonRepresentation(), privacy: .public)")
                }
            }
            if let diskWrites = payload.diskWriteExceptionDiagnostics, !diskWrites.isEmpty {
                for diag in diskWrites {
                    AppLogger.ui.error("MetricKit disk-write exception: \(diag.jsonRepresentation(), privacy: .public)")
                }
            }
        }
    }
}
