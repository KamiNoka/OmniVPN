import Foundation

public struct TrafficPoint: Identifiable, Codable {
    public var id: UUID
    public var timestamp: Date
    public var uploadBytesPerSec: Double
    public var downloadBytesPerSec: Double

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        uploadBytesPerSec: Double,
        downloadBytesPerSec: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.uploadBytesPerSec = uploadBytesPerSec
        self.downloadBytesPerSec = downloadBytesPerSec
    }
}

public struct TrafficSnapshot: Codable {
    public var currentUploadRate: Double    // B/s
    public var currentDownloadRate: Double  // B/s
    public var sessionUploadTotal: Int64    // bytes
    public var sessionDownloadTotal: Int64  // bytes
    public var totalUploadAllTime: Int64    // bytes
    public var totalDownloadAllTime: Int64  // bytes
    public var sessionDurationSeconds: TimeInterval

    public init(
        currentUploadRate: Double = 0,
        currentDownloadRate: Double = 0,
        sessionUploadTotal: Int64 = 0,
        sessionDownloadTotal: Int64 = 0,
        totalUploadAllTime: Int64 = 0,
        totalDownloadAllTime: Int64 = 0,
        sessionDurationSeconds: TimeInterval = 0
    ) {
        self.currentUploadRate = currentUploadRate
        self.currentDownloadRate = currentDownloadRate
        self.sessionUploadTotal = sessionUploadTotal
        self.sessionDownloadTotal = sessionDownloadTotal
        self.totalUploadAllTime = totalUploadAllTime
        self.totalDownloadAllTime = totalDownloadAllTime
        self.sessionDurationSeconds = sessionDurationSeconds
    }
}

public extension Int64 {
    var formattedBytes: String {
        let bytes = Double(self)
        if bytes >= 1_073_741_824 {
            return String(format: "%.2f GB", bytes / 1_073_741_824)
        } else if bytes >= 1_048_576 {
            return String(format: "%.1f MB", bytes / 1_048_576)
        } else if bytes >= 1024 {
            return String(format: "%.0f KB", bytes / 1024)
        } else {
            return "\(self) B"
        }
    }
}

public extension Double {
    var formattedSpeed: String {
        if self >= 1_048_576 {
            return String(format: "%.2f MB/s", self / 1_048_576)
        } else if self >= 1024 {
            return String(format: "%.1f KB/s", self / 1024)
        } else {
            return String(format: "%.0f B/s", self)
        }
    }
}
