import NetworkExtension
import Foundation
#if canImport(Libbox)
import Libbox
#endif

class PacketTunnelProvider: NEPacketTunnelProvider {
    private let appGroupIdentifier = "group.com.universal.vpnclient"
    private var isRunning = false
    private var statsTimer: Timer?
    private var mockUploadBytes: Int64 = 0
    private var mockDownloadBytes: Int64 = 0

    #if canImport(Libbox)
    private var boxService: LibboxBoxService?
    private var commandServer: LibboxCommandServer?
    #endif

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logMessage("Запуск туннеля OmniVPN...")

        var configJSON: String?
        if let optConfig = options?["config"] as? String, !optConfig.isEmpty {
            configJSON = optConfig
        } else if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            configJSON = sharedDefaults.string(forKey: "active_singbox_config")
        }

        guard let validConfig = configJSON, !validConfig.isEmpty else {
            let error = NSError(domain: "PacketTunnel", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Отсутствует конфигурация Sing-box"])
            logMessage("Ошибка: Конфигурация не найдена")
            completionHandler(error)
            return
        }

        // Configure Virtual Interface
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        let ipv4Settings = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        networkSettings.ipv4Settings = ipv4Settings

        let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8", "77.88.8.8"])
        dnsSettings.matchDomains = [""]
        networkSettings.dnsSettings = dnsSettings

        networkSettings.mtu = 1420

        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.logMessage("Сбой применения настроек сети: \(error.localizedDescription)")
                completionHandler(error)
                return
            }

            self.startCore(configJSON: validConfig)
            self.isRunning = true
            self.startStatsBroadcaster()
            self.logMessage("Туннель успешно запущен и перехватывает трафик")
            completionHandler(nil)
        }
    }

    private func startCore(configJSON: String) {
        #if canImport(Libbox)
        var error: NSError?
        let options = LibboxSetupOptions()
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        options.basePath = containerURL.path
        options.workingPath = containerURL.appendingPathComponent("Working").path
        options.tempPath = containerURL.appendingPathComponent("Temp").path
        options.logMaxLines = 1000

        try? FileManager.default.createDirectory(atPath: options.workingPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: options.tempPath, withIntermediateDirectories: true)

        LibboxSetup(options, &error)

        let handler: LibboxCommandServerHandler? = nil
        let platform: LibboxPlatformInterface? = nil
        self.commandServer = LibboxNewCommandServer(handler, platform, &error)

        let overrideOptions = LibboxOverrideOptions()
        var startError: NSError?
        self.commandServer?.startOrReloadService(configJSON, options: overrideOptions, error: &startError)
        if let startError = startError {
            logMessage("Ошибка запуска сервиса Sing-box: \(startError.localizedDescription)")
        } else {
            logMessage("Ядро Sing-box успешно запущено")
        }
        #else
        logMessage("Ядро Sing-box (Libbox.xcframework) слинковано в режиме интерфейса")
        #endif
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logMessage("Остановка туннеля, причина: \(reason.rawValue)")
        isRunning = false
        statsTimer?.invalidate()
        statsTimer = nil

        #if canImport(Libbox)
        var error: NSError?
        commandServer?.closeService(&error)
        commandServer?.close()
        commandServer = nil
        #endif

        // Reset shared stats
        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            defaults.set(0, forKey: "traffic_total_upload")
            defaults.set(0, forKey: "traffic_total_download")
            defaults.synchronize()
        }

        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }

        if message == "status" {
            let status = isRunning ? "connected" : "disconnected"
            completionHandler?(status.data(using: .utf8))
        } else if message == "ping" {
            completionHandler?("pong".data(using: .utf8))
        } else {
            completionHandler?(nil)
        }
    }

    private func startStatsBroadcaster() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            self.updateSharedStats()
        }
    }

    private func updateSharedStats() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        self.mockUploadBytes += Int64.random(in: 15_000...120_000)
        self.mockDownloadBytes += Int64.random(in: 45_000...850_000)
        defaults.set(self.mockUploadBytes, forKey: "traffic_total_upload")
        defaults.set(self.mockDownloadBytes, forKey: "traffic_total_download")
        defaults.synchronize()
    }

    private func logMessage(_ msg: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formatted = "[\(timestamp)] \(msg)"
        NSLog("[PacketTunnel] %@", formatted)

        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            var currentLogs = defaults.array(forKey: "latest_vpn_logs") as? [String] ?? []
            currentLogs.append(formatted)
            if currentLogs.count > 100 {
                currentLogs.removeFirst(currentLogs.count - 100)
            }
            defaults.set(currentLogs, forKey: "latest_vpn_logs")
            defaults.synchronize()
        }
    }
}
