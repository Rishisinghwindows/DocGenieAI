import SwiftUI

struct InsightsDashboardView: View {
    let files: [DocumentFile]

    // MARK: - Computed Insights

    private var totalSize: Int64 {
        files.reduce(0) { $0 + $1.fileSize }
    }

    private var thisWeekCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return files.filter { $0.importedAt > weekAgo }.count
    }

    private var expiringFiles: [DocumentFile] {
        files.filter { $0.isExpiringSoon || $0.isExpired }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    private var tagCounts: [(tag: FileTag, count: Int)] {
        var counts: [FileTag: Int] = [:]
        for file in files {
            if let tagName = file.tagName, let tag = FileTag(rawValue: tagName) {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    private var recentFiles: [DocumentFile] {
        Array(
            files
                .sorted { $0.importedAt > $1.importedAt }
                .prefix(3)
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            if !files.isEmpty {
                statsCard
                    .staggeredAppear(index: 0)
            }

            if !expiringFiles.isEmpty {
                expiryCard
                    .staggeredAppear(index: 1)
            }

            if !tagCounts.isEmpty {
                tagCard
                    .staggeredAppear(index: 2)
            }

            if !recentFiles.isEmpty {
                recentCard
                    .staggeredAppear(index: 3)
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        AppCard(style: .glass) {
            HStack(spacing: 0) {
                statItem(
                    icon: "doc.fill",
                    color: .appPrimary,
                    value: "\(files.count)",
                    label: "files"
                )

                Spacer()

                statItem(
                    icon: "internaldrive",
                    color: .appAccent,
                    value: totalSize.formattedFileSize,
                    label: "total"
                )

                Spacer()

                statItem(
                    icon: "calendar.badge.plus",
                    color: .appSuccess,
                    value: "\(thisWeekCount)",
                    label: "this week"
                )
            }
        }
    }

    private func statItem(icon: String, color: Color, value: String, label: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appText)
                Text(label)
                    .font(.appMicro)
                    .foregroundStyle(Color.appTextDim)
            }
        }
    }

    // MARK: - Expiry Card

    private var expiryCard: some View {
        AppCard(style: .glass) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appWarning)
                    Text("Expiring Soon")
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appText)
                    Spacer()
                }

                ForEach(expiringFiles.prefix(2)) { file in
                    HStack(spacing: AppSpacing.xs) {
                        FileTypeIcon(fileExtension: file.fileExtension, size: 12)

                        Text(file.name)
                            .font(.appMicro)
                            .foregroundStyle(Color.appText)
                            .lineLimit(1)

                        Spacer()

                        if file.isExpired {
                            Text("Expired")
                                .font(.appMicro)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.appDanger)
                        } else if let days = file.daysUntilExpiry {
                            Text("\(days)d left")
                                .font(.appMicro)
                                .fontWeight(.medium)
                                .foregroundStyle(days <= 7 ? Color.appDanger : Color.appWarning)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tag Card

    private var tagCard: some View {
        AppCard(style: .glass) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appPrimary)
                    Text("Top Categories")
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appText)
                    Spacer()
                }

                HStack(spacing: AppSpacing.sm) {
                    ForEach(tagCounts, id: \.tag) { item in
                        HStack(spacing: 4) {
                            Image(systemName: item.tag.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(item.tag.color)
                            Text("\(item.tag.rawValue): \(item.count)")
                                .font(.appMicro)
                                .foregroundStyle(Color.appText)
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(item.tag.color.opacity(0.12), in: Capsule())
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Recent Card

    private var recentCard: some View {
        AppCard(style: .glass) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                    Text("Recent")
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appText)
                    Spacer()
                }

                ForEach(recentFiles.prefix(3)) { file in
                    HStack(spacing: AppSpacing.xs) {
                        FileTypeIcon(fileExtension: file.fileExtension, size: 12)

                        Text(file.name)
                            .font(.appMicro)
                            .foregroundStyle(Color.appText)
                            .lineLimit(1)

                        Spacer()

                        Text(file.importedAt.relativeDisplay)
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextDim)
                    }
                }
            }
        }
    }
}
