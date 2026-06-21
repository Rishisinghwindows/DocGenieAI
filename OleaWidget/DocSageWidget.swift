//
//  DocSageWidget.swift
//  DocSageWidget
//
//  Created by pawan singh on 15/03/26.
//

import WidgetKit
import SwiftUI

// MARK: - Shared Constants

private enum WidgetConstants {
    static let suiteName = "group.com.docgenieai.shared"
    static let recentDocsKey = "widget_recent_documents"
    static let statsKey = "widget_document_stats"
}

// MARK: - Shared Data Models

struct WidgetDocumentItem: Codable, Identifiable {
    let id: String
    let name: String
    let fileExtension: String
    let fileSize: Int64
    let importedAt: Date
}

struct WidgetDocumentStats: Codable {
    let totalCount: Int
    let totalSizeBytes: Int64
    let thisWeekCount: Int
}

// MARK: - Color Extensions for Widget

private extension Color {
    static let widgetPrimary = Color(red: 0x63/255, green: 0x66/255, blue: 0xF1/255)
    static let widgetAccent = Color(red: 0x06/255, green: 0xB6/255, blue: 0xD4/255)
    static let widgetSuccess = Color(red: 0x10/255, green: 0xB9/255, blue: 0x81/255)
    static let widgetBGDark = Color(red: 0x0F/255, green: 0x17/255, blue: 0x2A/255)
    static let widgetBGCard = Color(red: 0x1E/255, green: 0x29/255, blue: 0x3B/255)
    static let widgetText = Color(red: 0xF1/255, green: 0xF5/255, blue: 0xF9/255)
    static let widgetTextMuted = Color(red: 0x94/255, green: 0xA3/255, blue: 0xB8/255)
}

// MARK: - Helper: File Type Icon

private func fileTypeIcon(for ext: String) -> String {
    switch ext.lowercased() {
    case "pdf": return "doc.richtext.fill"
    case "doc", "docx": return "doc.text.fill"
    case "xls", "xlsx": return "tablecells.fill"
    case "ppt", "pptx": return "play.rectangle.fill"
    case "txt", "csv", "xml", "rtf": return "doc.plaintext.fill"
    case "jpg", "jpeg", "png", "heic", "webp", "bmp", "gif", "tiff": return "photo.fill"
    default: return "doc.fill"
    }
}

private func fileTypeColor(for ext: String) -> Color {
    switch ext.lowercased() {
    case "pdf": return .red
    case "doc", "docx": return .blue
    case "xls", "xlsx": return .green
    case "ppt", "pptx": return .orange
    case "txt", "csv", "xml", "rtf": return .gray
    case "jpg", "jpeg", "png", "heic", "webp", "bmp", "gif", "tiff": return .purple
    default: return Color.widgetPrimary
    }
}

private func formattedSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

private func shortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

// MARK: - 1. Recent Documents Widget

struct RecentDocsEntry: TimelineEntry {
    let date: Date
    let documents: [WidgetDocumentItem]
}

struct RecentDocsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentDocsEntry {
        RecentDocsEntry(date: .now, documents: sampleDocs)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentDocsEntry) -> Void) {
        completion(RecentDocsEntry(date: .now, documents: loadDocuments()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentDocsEntry>) -> Void) {
        let entry = RecentDocsEntry(date: .now, documents: loadDocuments())
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60)))
        completion(timeline)
    }

    private func loadDocuments() -> [WidgetDocumentItem] {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.suiteName),
              let data = defaults.data(forKey: WidgetConstants.recentDocsKey),
              let docs = try? JSONDecoder().decode([WidgetDocumentItem].self, from: data) else {
            return []
        }
        return docs
    }

    private var sampleDocs: [WidgetDocumentItem] {
        [
            WidgetDocumentItem(id: "1", name: "Invoice 2026", fileExtension: "pdf", fileSize: 245_000, importedAt: .now),
            WidgetDocumentItem(id: "2", name: "Meeting Notes", fileExtension: "docx", fileSize: 120_000, importedAt: .now.addingTimeInterval(-3600)),
            WidgetDocumentItem(id: "3", name: "Budget Report", fileExtension: "xlsx", fileSize: 580_000, importedAt: .now.addingTimeInterval(-7200)),
            WidgetDocumentItem(id: "4", name: "Vacation Photo", fileExtension: "jpg", fileSize: 2_400_000, importedAt: .now.addingTimeInterval(-86400)),
        ]
    }
}

struct RecentDocsWidgetView: View {
    var entry: RecentDocsEntry
    @Environment(\.widgetFamily) var family

    private var visibleDocs: [WidgetDocumentItem] {
        let count = family == .systemSmall ? 2 : 4
        return Array(entry.documents.prefix(count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.widgetAccent)
                Text("Recent Documents")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.widgetText)
                Spacer()
            }

            if visibleDocs.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.widgetTextMuted)
                        Text("No documents yet")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.widgetTextMuted)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(visibleDocs) { doc in
                    Link(destination: URL(string: "docsage://open?id=\(doc.id)")!) {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(fileTypeColor(for: doc.fileExtension).opacity(0.2))
                                .frame(width: family == .systemSmall ? 28 : 32, height: family == .systemSmall ? 28 : 32)
                                .overlay(
                                    Image(systemName: fileTypeIcon(for: doc.fileExtension))
                                        .font(.system(size: family == .systemSmall ? 12 : 14))
                                        .foregroundStyle(fileTypeColor(for: doc.fileExtension))
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(doc.name)
                                    .font(.system(size: family == .systemSmall ? 11 : 12, weight: .medium))
                                    .foregroundStyle(Color.widgetText)
                                    .lineLimit(1)

                                if family == .systemMedium {
                                    HStack(spacing: 4) {
                                        Text(doc.fileExtension.uppercased())
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(fileTypeColor(for: doc.fileExtension))
                                        Text(shortDate(doc.importedAt))
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.widgetTextMuted)
                                    }
                                } else {
                                    Text(shortDate(doc.importedAt))
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.widgetTextMuted)
                                }
                            }

                            Spacer(minLength: 0)

                            if family == .systemMedium {
                                Text(formattedSize(doc.fileSize))
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.widgetTextMuted)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.widgetBGDark, Color.widgetBGCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct RecentDocumentsWidget: Widget {
    let kind: String = "RecentDocumentsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentDocsProvider()) { entry in
            RecentDocsWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Documents")
        .description("Quick access to your recently imported documents.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 2. Quick Actions Widget

struct QuickActionsEntry: TimelineEntry {
    let date: Date
}

struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        QuickActionsEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(QuickActionsEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        let entry = QuickActionsEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

private struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let deepLink: String
}

private let quickActions = [
    QuickAction(title: "Scan", icon: "doc.viewfinder.fill", color: Color.widgetPrimary, deepLink: "docsage://scan"),
    QuickAction(title: "Chat", icon: "bubble.left.and.bubble.right.fill", color: Color.widgetAccent, deepLink: "docsage://chat"),
    QuickAction(title: "OCR", icon: "text.viewfinder", color: Color.widgetSuccess, deepLink: "docsage://ocr"),
    QuickAction(title: "Compress", icon: "arrow.down.doc.fill", color: .orange, deepLink: "docsage://compress"),
]

struct QuickActionsWidgetView: View {
    var entry: QuickActionsEntry

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.widgetAccent)
                Text("Quick Actions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.widgetText)
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(quickActions) { action in
                    Link(destination: URL(string: action.deepLink)!) {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(action.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: action.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(action.color)
                            }
                            Text(action.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.widgetText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.widgetBGDark, Color.widgetBGCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct QuickActionsWidget: Widget {
    let kind: String = "QuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Actions")
        .description("Quickly scan, chat, OCR, or compress documents.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - 3. Document Stats Widget

struct DocStatsEntry: TimelineEntry {
    let date: Date
    let stats: WidgetDocumentStats
}

struct DocStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> DocStatsEntry {
        DocStatsEntry(date: .now, stats: WidgetDocumentStats(totalCount: 42, totalSizeBytes: 256_000_000, thisWeekCount: 7))
    }

    func getSnapshot(in context: Context, completion: @escaping (DocStatsEntry) -> Void) {
        completion(DocStatsEntry(date: .now, stats: loadStats()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DocStatsEntry>) -> Void) {
        let entry = DocStatsEntry(date: .now, stats: loadStats())
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60)))
        completion(timeline)
    }

    private func loadStats() -> WidgetDocumentStats {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.suiteName),
              let data = defaults.data(forKey: WidgetConstants.statsKey),
              let stats = try? JSONDecoder().decode(WidgetDocumentStats.self, from: data) else {
            return WidgetDocumentStats(totalCount: 0, totalSizeBytes: 0, thisWeekCount: 0)
        }
        return stats
    }
}

struct DocStatsWidgetView: View {
    var entry: DocStatsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.widgetAccent)
                Text("Document Stats")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.widgetText)
                Spacer()
                Text("DocSage")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.widgetTextMuted)
            }

            HStack(spacing: 0) {
                // Total Documents
                statCard(
                    icon: "doc.on.doc.fill",
                    iconColor: Color.widgetPrimary,
                    value: "\(entry.stats.totalCount)",
                    label: "Total Docs"
                )

                Spacer(minLength: 4)

                // Storage Used
                statCard(
                    icon: "internaldrive.fill",
                    iconColor: .widgetAccent,
                    value: formattedSize(entry.stats.totalSizeBytes),
                    label: "Storage"
                )

                Spacer(minLength: 4)

                // This Week
                statCard(
                    icon: "calendar.badge.plus",
                    iconColor: Color.widgetSuccess,
                    value: "\(entry.stats.thisWeekCount)",
                    label: "This Week"
                )
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.widgetBGDark, Color.widgetBGCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func statCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.widgetText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.widgetTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct DocumentStatsWidget: Widget {
    let kind: String = "DocumentStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DocStatsProvider()) { entry in
            DocStatsWidgetView(entry: entry)
        }
        .configurationDisplayName("Document Stats")
        .description("See your document collection at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Recent Docs - Small", as: .systemSmall) {
    RecentDocumentsWidget()
} timeline: {
    RecentDocsEntry(date: .now, documents: [
        WidgetDocumentItem(id: "1", name: "Invoice 2026", fileExtension: "pdf", fileSize: 245_000, importedAt: .now),
        WidgetDocumentItem(id: "2", name: "Meeting Notes", fileExtension: "docx", fileSize: 120_000, importedAt: .now),
    ])
}

#Preview("Recent Docs - Medium", as: .systemMedium) {
    RecentDocumentsWidget()
} timeline: {
    RecentDocsEntry(date: .now, documents: [
        WidgetDocumentItem(id: "1", name: "Invoice 2026", fileExtension: "pdf", fileSize: 245_000, importedAt: .now),
        WidgetDocumentItem(id: "2", name: "Meeting Notes", fileExtension: "docx", fileSize: 120_000, importedAt: .now),
        WidgetDocumentItem(id: "3", name: "Budget Report", fileExtension: "xlsx", fileSize: 580_000, importedAt: .now),
        WidgetDocumentItem(id: "4", name: "Vacation Photo", fileExtension: "jpg", fileSize: 2_400_000, importedAt: .now),
    ])
}

#Preview("Quick Actions", as: .systemSmall) {
    QuickActionsWidget()
} timeline: {
    QuickActionsEntry(date: .now)
}

#Preview("Document Stats", as: .systemMedium) {
    DocumentStatsWidget()
} timeline: {
    DocStatsEntry(date: .now, stats: WidgetDocumentStats(totalCount: 42, totalSizeBytes: 256_000_000, thisWeekCount: 7))
}
