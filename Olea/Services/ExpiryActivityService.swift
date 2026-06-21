import ActivityKit
import Foundation
import SwiftData

/// Manages Live Activities for documents approaching their expiry date. Starts
/// an activity once the doc enters the user's reminder window, updates it daily
/// (Live Activity content state has an 8-hour stale window — we refresh on app
/// launch), and ends it when the doc expires or is deleted.
@MainActor
final class ExpiryActivityService {
    static let shared = ExpiryActivityService()
    private init() {}

    private let calendar = Calendar.current

    /// Reconcile Live Activities against the current set of documents. Call on
    /// app launch and whenever the user adds/edits an expiry date.
    func reconcile(modelContext: ModelContext) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.ui.info("Live Activities disabled by user — skipping reconcile.")
            return
        }

        let descriptor = FetchDescriptor<DocumentFile>(
            predicate: #Predicate<DocumentFile> { $0.expiryDate != nil && $0.isInVault == false }
        )
        let docs = (try? modelContext.fetch(descriptor)) ?? []

        let active = Set(Activity<ExpiringDocAttributes>.activities.map { $0.attributes.documentID })
        var keep = Set<String>()

        for doc in docs {
            guard let expiry = doc.expiryDate else { continue }
            let days = daysUntil(expiry)
            let window = doc.expiryReminderDays ?? 30

            // Start an activity only when within the reminder window. Don't show
            // for docs expiring far in the future — that would be visual spam.
            if days <= window {
                let id = doc.id.uuidString
                keep.insert(id)
                if active.contains(id) {
                    update(activityFor: id, daysRemaining: days, expiryDate: expiry)
                } else {
                    start(document: doc, daysRemaining: days, expiryDate: expiry)
                }
            }
        }

        // End any activity whose document is no longer in the reminder window.
        for activity in Activity<ExpiringDocAttributes>.activities {
            if !keep.contains(activity.attributes.documentID) {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }
    }

    /// End all activities — used when the user disables the feature or signs out.
    func endAll() async {
        for activity in Activity<ExpiringDocAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Helpers

    private func start(document: DocumentFile, daysRemaining: Int, expiryDate: Date) {
        let attributes = ExpiringDocAttributes(
            documentID: document.id.uuidString,
            documentName: document.aiSuggestedName ?? document.name,
            documentType: document.tag?.rawValue ?? "Document",
            iconSystemName: iconForDocument(document)
        )
        let state = ExpiringDocAttributes.ContentState(
            daysRemaining: daysRemaining,
            expiryDate: expiryDate
        )
        let content = ActivityContent(state: state, staleDate: nextDay(from: Date()))

        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            AppLogger.ui.info("Started Live Activity for \(document.name, privacy: .public) (\(daysRemaining) days).")
        } catch {
            AppLogger.ui.error("Live Activity start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func update(activityFor id: String, daysRemaining: Int, expiryDate: Date) {
        guard let activity = Activity<ExpiringDocAttributes>.activities.first(where: { $0.attributes.documentID == id }) else { return }
        let state = ExpiringDocAttributes.ContentState(daysRemaining: daysRemaining, expiryDate: expiryDate)
        let content = ActivityContent(state: state, staleDate: nextDay(from: Date()))
        Task { await activity.update(content) }
    }

    private func daysUntil(_ date: Date) -> Int {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    private func nextDay(from date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(86400)
    }

    private func iconForDocument(_ doc: DocumentFile) -> String {
        switch doc.aiContentType {
        case "id": return "person.text.rectangle"
        case "contract": return "doc.text.below.ecg"
        case "invoice": return "doc.text"
        case "receipt": return "receipt"
        case "statement": return "chart.bar.doc.horizontal"
        default:
            switch doc.tag {
            case .legal: return "scale.3d"
            case .invoice: return "doc.text"
            case .receipt: return "receipt"
            default: return "calendar.badge.clock"
            }
        }
    }
}
