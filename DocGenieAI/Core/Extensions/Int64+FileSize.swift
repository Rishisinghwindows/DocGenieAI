import Foundation

extension Int64 {
    private nonisolated(unsafe) static let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    var formattedFileSize: String {
        Int64.fileSizeFormatter.string(fromByteCount: self)
    }
}
