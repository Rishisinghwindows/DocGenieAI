//
//  WidgetDataService.swift
//  DocGenieAI
//
//  Service that syncs app data to shared UserDefaults
//  so home screen widgets can display recent documents and stats.
//

import Foundation
import WidgetKit

/// Lightweight model mirroring the widget target's `WidgetDocumentItem`.
/// Kept in sync manually -- both sides decode the same JSON.
private struct WidgetDocumentItem: Codable {
    let id: String
    let name: String
    let fileExtension: String
    let fileSize: Int64
    let importedAt: Date
}

/// Lightweight model mirroring the widget target's `WidgetDocumentStats`.
private struct WidgetDocumentStats: Codable {
    let totalCount: Int
    let totalSizeBytes: Int64
    let thisWeekCount: Int
}

@MainActor
final class WidgetDataService {
    static let shared = WidgetDataService()

    private let suiteName = "group.com.docgenieai.shared"
    private let recentDocsKey = "widget_recent_documents"
    private let statsKey = "widget_document_stats"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private init() {}

    // MARK: - Recent Documents

    /// Saves the top 4 most-recently-imported documents to shared storage
    /// so the Recent Documents widget can display them.
    func updateRecentDocuments(files: [DocumentFile]) {
        let topFiles = files
            .sorted { $0.importedAt > $1.importedAt }
            .prefix(4)

        let items = topFiles.map { file in
            WidgetDocumentItem(
                id: file.id.uuidString,
                name: file.name,
                fileExtension: file.fileExtension,
                fileSize: file.fileSize,
                importedAt: file.importedAt
            )
        }

        guard let data = try? JSONEncoder().encode(Array(items)) else { return }
        sharedDefaults?.set(data, forKey: recentDocsKey)

        WidgetCenter.shared.reloadTimelines(ofKind: "RecentDocumentsWidget")
    }

    // MARK: - Document Stats

    /// Saves aggregate document statistics to shared storage
    /// so the Document Stats widget can display them.
    func updateDocumentStats(totalCount: Int, totalSize: Int64, thisWeekCount: Int) {
        let stats = WidgetDocumentStats(
            totalCount: totalCount,
            totalSizeBytes: totalSize,
            thisWeekCount: thisWeekCount
        )

        guard let data = try? JSONEncoder().encode(stats) else { return }
        sharedDefaults?.set(data, forKey: statsKey)

        WidgetCenter.shared.reloadTimelines(ofKind: "DocumentStatsWidget")
    }

    // MARK: - Convenience

    /// Computes stats from an array of all documents and pushes both
    /// recent documents and stats to the widget in one call.
    func syncAllWidgetData(allFiles: [DocumentFile]) {
        // Recent documents
        updateRecentDocuments(files: allFiles)

        // Stats
        let totalCount = allFiles.count
        let totalSize = allFiles.reduce(Int64(0)) { $0 + $1.fileSize }

        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let thisWeekCount = allFiles.filter { $0.importedAt >= startOfWeek }.count

        updateDocumentStats(totalCount: totalCount, totalSize: totalSize, thisWeekCount: thisWeekCount)
    }
}
