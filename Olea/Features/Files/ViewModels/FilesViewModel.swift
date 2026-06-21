import SwiftUI
import SwiftData

@MainActor
@Observable
final class FilesViewModel {
    var searchText = ""
    var selectedCategory: FileCategory = .all
    var sortOption: FileSortOption = .dateDesc
    var searchScope: SearchScope = .all
    var selectedTag: FileTag?

    enum SearchScope: String, CaseIterable {
        case all = "All"
        case name = "Name"
        case content = "Content"
    }

    private var cachedCounts: [FileCategory: Int] = [:]
    private var cachedCountsHash = 0

    func filteredAndSorted(_ files: [DocumentFile]) -> [DocumentFile] {
        // Exclude vault files from main file list
        var result = files.filter { !$0.isInVault }

        // Filter by category
        if selectedCategory != .all {
            result = result.filter { selectedCategory.extensions.contains($0.fileExtension.lowercased()) }
        }

        // Filter by tag
        if let tag = selectedTag {
            result = result.filter { $0.tagName == tag.rawValue }
        }

        // Filter by search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { file in
                switch searchScope {
                case .name:
                    return file.name.lowercased().contains(query) || file.fileExtension.lowercased().contains(query)
                case .content:
                    return file.ocrTextCache?.lowercased().contains(query) ?? false
                case .all:
                    return file.name.lowercased().contains(query)
                        || file.fileExtension.lowercased().contains(query)
                        || (file.ocrTextCache?.lowercased().contains(query) ?? false)
                }
            }
        }

        // Sort
        switch sortOption {
        case .dateDesc:
            result.sort { ($0.importedAt) > ($1.importedAt) }
        case .dateAsc:
            result.sort { ($0.importedAt) < ($1.importedAt) }
        case .nameAsc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .sizeDesc:
            result.sort { $0.fileSize > $1.fileSize }
        case .sizeAsc:
            result.sort { $0.fileSize < $1.fileSize }
        case .typeAsc:
            result.sort { $0.fileExtension < $1.fileExtension }
        }

        return result
    }

    func categoryCount(_ category: FileCategory, in files: [DocumentFile]) -> Int {
        // Exclude vault files from counts
        let nonVaultFiles = files.filter { !$0.isInVault }
        // Recompute when file IDs or extensions change (not just count)
        let currentHash = computeHash(nonVaultFiles)
        if currentHash != cachedCountsHash {
            rebuildCategoryCounts(nonVaultFiles, hash: currentHash)
        }
        return cachedCounts[category] ?? 0
    }

    private func computeHash(_ files: [DocumentFile]) -> Int {
        var hasher = Hasher()
        for file in files {
            hasher.combine(file.id)
            hasher.combine(file.fileExtension)
        }
        return hasher.finalize()
    }

    private func rebuildCategoryCounts(_ files: [DocumentFile], hash: Int) {
        var counts: [FileCategory: Int] = [.all: files.count]
        for file in files {
            let ext = file.fileExtension.lowercased()
            for category in FileCategory.allCases where category != .all {
                if category.extensions.contains(ext) {
                    counts[category, default: 0] += 1
                }
            }
        }
        cachedCounts = counts
        cachedCountsHash = hash
    }

    func recentFiles(_ files: [DocumentFile], limit: Int = 5) -> [DocumentFile] {
        files
            .filter { $0.lastOpenedAt != nil && !$0.isInVault }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }
}
