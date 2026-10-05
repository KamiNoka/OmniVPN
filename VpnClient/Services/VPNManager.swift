import Foundation
import NetworkExtension
import Combine

@MainActor
public class VPNManager: ObservableObject {
    public static let shared = VPNManager()

    public static let appGroupIdentifier = "group.com.universal.vpnclient"
    public static let tunnelBundleIdentifier = "com.universal.vpnclient.PacketTunnel"

    @Published public var vpnStatus: NEVPNStatus = .disconnected
    @Published public var isConnecting: Bool = false
    @Published public var lastError: String?
    @Published public var sessionDuration: TimeInterval = 0

    private var providerManager: NETunnelProviderManager?
    private var statusObserver: Any?
    private var durationTimer: Timer?
    private var connectionStartTime: Date?

    public init() {
        setupStatusObserver()
        Task {
            await reloadManager()
        }
    }

    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        durationTimer?.invalidate()
    }

    private func setupStatusObserver() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.updateVPNStatus()
        }
    }

    public func reloadManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let existing = managers.first {
                self.providerManager = existing
            } else {
                let newManager = NETunnelProviderManager()
                newManager.localizedDescription = "OmniVPN (Sing-box)"
                let proto = NETunnelProviderProtocol()
                proto.providerBundleIdentifier = Self.tunnelBundleIdentifier
                proto.serverAddress = "Sing-box Core"
                newManager.protocolConfiguration = proto
                newManager.isEnabled = true
                try await newManager.saveToPreferences()
                self.providerManager = newManager
            }
            self.updateVPNStatus()
        } catch {
            self.lastError = "Ошибка инициализации VPN: \(error.localizedDescription)"
        }
    }

    private func updateVPNStatus() {
        guard let manager = providerManager else {
            vpnStatus = .disconnected
            isConnecting = false
            return
        }

        let newStatus = manager.connection.status
        self.vpnStatus = newStatus
        self.isConnecting = (newStatus == .connecting || newStatus == .reasserting)

        if newStatus == .connected {
            if connectionStartTime == nil {
                connectionStartTime = Date()
                startDurationTimer()
            }
        } else if newStatus == .disconnected || newStatus == .invalid {
            connectionStartTime = nil
            durationTimer?.invalidate()
            durationTimer = nil
            sessionDuration = 0
        }
    }

    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let start = self.connectionStartTime else { return }
                self.sessionDuration = Date().timeIntervalSince(start)
            }
        }
    }

    public func connect(configJSON: String) async throws {
        guard let manager = providerManager else {
            await reloadManager()
            guard let reloaded = providerManager else {
                throw NSError(domain: "VPNManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "VPN менеджер недоступен"])
            }
            return try await connectWithManager(reloaded, configJSON: configJSON)
        }
        try await connectWithManager(manager, configJSON: configJSON)
    }

    private func connectWithManager(_ manager: NETunnelProviderManager, configJSON: String) async throws {
        manager.isEnabled = true
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()

        // Save active config to App Group for PacketTunnelProvider to read
        if let sharedDefaults = UserDefaults(suiteName: Self.appGroupIdentifier) {
            sharedDefaults.set(configJSON, forKey: "active_singbox_config")
            sharedDefaults.synchronize()
        }

        let options: [String: NSObject] = [
            "config": configJSON as NSString
        ]

        try (manager.connection as? NETunnelProviderSession)?.startVPNTunnel(options: options)
    }

    public func disconnect() {
        providerManager?.connection.stopVPNTunnel()
        connectionStartTime = nil
        durationTimer?.invalidate()
        durationTimer = nil
        sessionDuration = 0
        vpnStatus = .disconnected
    }

    public func sendProviderMessage(_ message: String) async -> String? {
        guard let session = providerManager?.connection as? NETunnelProviderSession,
              let data = message.data(using: .utf8) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            do {
                try session.sendProviderMessage(data) { responseData in
                    if let res = responseData, let resString = String(data: res, encoding: .utf8) {
                        continuation.resume(returning: resString)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
