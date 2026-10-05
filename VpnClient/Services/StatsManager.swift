import Foundation
import Combine

@MainActor
public class StatsManager: ObservableObject {
    public static let shared = StatsManager()

    @Published public var currentSnapshot = TrafficSnapshot()
    @Published public var trafficHistory: [TrafficPoint] = []
    @Published public var recentLogs: [String] = []

    private var pollTimer: Timer?
    private var lastUploadedTotal: Int64 = 0
    private var lastDownloadedTotal: Int64 = 0
    private var lastPollTime: Date = Date()

    private let maxHistoryPoints = 60
    private let appGroupIdentifier = "group.com.universal.vpnclient"

    public init() {
        loadPersistedTotals()
    }

    public func startPolling() {
        stopPolling()
        lastPollTime = Date()
        lastUploadedTotal = 0
        lastDownloadedTotal = 0

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchLatestStats()
            }
        }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        currentSnapshot.currentUploadRate = 0
        currentSnapshot.currentDownloadRate = 0
    }

    private func fetchLatestStats() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        let currentTotalUp = defaults.int64(forKey: "traffic_total_upload")
        let currentTotalDown = defaults.int64(forKey: "traffic_total_download")

        let now = Date()
        let interval = max(0.5, now.timeIntervalSince(lastPollTime))
        lastPollTime = now

        var uploadSpeed: Double = 0
        var downloadSpeed: Double = 0

        if lastUploadedTotal > 0 && currentTotalUp >= lastUploadedTotal {
            let diffUp = currentTotalUp - lastUploadedTotal
            uploadSpeed = Double(diffUp) / interval
        }

        if lastDownloadedTotal > 0 && currentTotalDown >= lastDownloadedTotal {
            let diffDown = currentTotalDown - lastDownloadedTotal
            downloadSpeed = Double(diffDown) / interval
        }

        lastUploadedTotal = currentTotalUp
        lastDownloadedTotal = currentTotalDown

        currentSnapshot.currentUploadRate = uploadSpeed
        currentSnapshot.currentDownloadRate = downloadSpeed
        currentSnapshot.sessionUploadTotal = currentTotalUp
        currentSnapshot.sessionDownloadTotal = currentTotalDown
        currentSnapshot.totalUploadAllTime += Int64(uploadSpeed * interval)
        currentSnapshot.totalDownloadAllTime += Int64(downloadSpeed * interval)

        // Append to Swift Charts history
        let point = TrafficPoint(
            timestamp: now,
            uploadBytesPerSec: uploadSpeed,
            downloadBytesPerSec: downloadSpeed
        )
        trafficHistory.append(point)
        if trafficHistory.count > maxHistoryPoints {
            trafficHistory.removeFirst(trafficHistory.count - maxHistoryPoints)
        }

        // Fetch logs
        if let logs = defaults.array(forKey: "latest_vpn_logs") as? [String] {
            self.recentLogs = logs
        }

        persistTotals()
    }

    private func persistTotals() {
        UserDefaults.standard.set(currentSnapshot.totalUploadAllTime, forKey: "total_upload_all_time")
        UserDefaults.standard.set(currentSnapshot.totalDownloadAllTime, forKey: "total_download_all_time")
    }

    private func loadPersistedTotals() {
        currentSnapshot.totalUploadAllTime = UserDefaults.standard.int64(forKey: "total_upload_all_time")
        currentSnapshot.totalDownloadAllTime = UserDefaults.standard.int64(forKey: "total_download_all_time")
    }
}

private extension UserDefaults {
    func int64(forKey key: String) -> Int64 {
        return object(forKey: key) as? Int64 ?? (object(forKey: key) as? NSNumber)?.int64Value ?? 0
    }
}
