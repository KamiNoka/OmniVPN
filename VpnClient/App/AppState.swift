import Foundation
import SwiftUI
import Combine

@MainActor
public class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var servers: [ServerNode] = []
    @Published public var selectedNodeId: UUID?
    @Published public var subscriptions: [Subscription] = []
    @Published public var routingMode: RoutingMode = .ruleBased
    @Published public var dnsServer: String = "https://1.1.1.1/dns-query"
    @Published public var killSwitch: Bool = false
    @Published public var customRules: [CustomRouteRule] = []

    public var selectedNode: ServerNode? {
        get {
            if let id = selectedNodeId {
                return servers.first(where: { $0.id == id }) ?? servers.first
            }
            return servers.first
        }
        set {
            selectedNodeId = newValue?.id
            saveServers()
        }
    }

    private let serversKey = "saved_server_nodes"
    private let selectedIdKey = "saved_selected_node_id"
    private let subscriptionsKey = "saved_subscriptions"
    private let routingModeKey = "saved_routing_mode"
    private let dnsServerKey = "saved_dns_server"
    private let killSwitchKey = "saved_kill_switch"

    public init() {
        loadState()
        if servers.isEmpty {
            seedDefaultNodes()
        }
    }

    // MARK: - State Management

    public func addNode(_ node: ServerNode) {
        servers.append(node)
        if selectedNodeId == nil {
            selectedNodeId = node.id
        }
        saveServers()
    }

    public func deleteNode(at offsets: IndexSet) {
        servers.remove(atOffsets: offsets)
        if let sel = selectedNodeId, !servers.contains(where: { $0.id == sel }) {
            selectedNodeId = servers.first?.id
        }
        saveServers()
    }

    public func addSubscription(name: String, url: String, content: String) {
        let parsedNodes = SubscriptionParser.shared.parse(content: content)
        let sub = Subscription(name: name, url: url, lastUpdated: Date(), nodes: parsedNodes)
        subscriptions.append(sub)
        servers.append(contentsOf: parsedNodes)
        if selectedNodeId == nil {
            selectedNodeId = parsedNodes.first?.id
        }
        saveSubscriptions()
        saveServers()
    }

    public func pingAllServers() async {
        let results = await PingService.shared.pingAll(nodes: servers)
        for i in 0..<servers.count {
            if let ms = results[servers[i].id] {
                servers[i].pingMs = ms
                servers[i].lastTested = Date()
            }
        }
        saveServers()
    }

    // MARK: - Persistence

    private func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: serversKey)
        }
        if let sel = selectedNodeId {
            UserDefaults.standard.set(sel.uuidString, forKey: selectedIdKey)
        }
    }

    private func saveSubscriptions() {
        if let encoded = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(encoded, forKey: subscriptionsKey)
        }
    }

    public func saveSettings() {
        UserDefaults.standard.set(routingMode.rawValue, forKey: routingModeKey)
        UserDefaults.standard.set(dnsServer, forKey: dnsServerKey)
        UserDefaults.standard.set(killSwitch, forKey: killSwitchKey)
    }

    private func loadState() {
        if let data = UserDefaults.standard.data(forKey: serversKey),
           let decoded = try? JSONDecoder().decode([ServerNode].self, from: data) {
            self.servers = decoded
        }

        if let selStr = UserDefaults.standard.string(forKey: selectedIdKey),
           let uuid = UUID(uuidString: selStr) {
            self.selectedNodeId = uuid
        }

        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let decoded = try? JSONDecoder().decode([Subscription].self, from: data) {
            self.subscriptions = decoded
        }

        if let modeStr = UserDefaults.standard.string(forKey: routingModeKey),
           let mode = RoutingMode(rawValue: modeStr) {
            self.routingMode = mode
        }

        if let dns = UserDefaults.standard.string(forKey: dnsServerKey) {
            self.dnsServer = dns
        }

        self.killSwitch = UserDefaults.standard.bool(forKey: killSwitchKey)
    }

    private func seedDefaultNodes() {
        let node1 = ServerNode(
            name: "Frankfurt Reality (VLESS)",
            server: "de1.omnivpn.net",
            port: 443,
            protocolType: .vless,
            countryCode: "DE",
            uuid: "a2b3c4d5-e6f7-4890-abcd-1234567890ab",
            tlsEnabled: true,
            sni: "gateway.icloud.com",
            fingerprint: "chrome",
            realityPublicKey: "xFRn82xPqL9_mR7P8_8Jq1vB9xK4o9pQ_wL3yV8=",
            realityShortId: "6ba81106"
        )

        let node2 = ServerNode(
            name: "Amsterdam Hysteria 2",
            server: "nl1.omnivpn.net",
            port: 443,
            protocolType: .hysteria2,
            countryCode: "NL",
            password: "SecurePassWord123!",
            tlsEnabled: true,
            sni: "speedtest.net"
        )

        let node3 = ServerNode(
            name: "Helsinki WireGuard",
            server: "fi1.omnivpn.net",
            port: 51820,
            protocolType: .wireguard,
            countryCode: "FI",
            privateKey: "aGVsbG93b3JsZHByaXZhdGVrZXlleGFtcGxlMTI=",
            peerPublicKey: "cGVlcnB1YmxpY2tleWV4YW1wbGUxMjM0NTY3OA==",
            localAddress: "10.14.0.2/32"
        )

        let node4 = ServerNode(
            name: "Stockholm Shadowsocks",
            server: "se1.omnivpn.net",
            port: 8388,
            protocolType: .shadowsocks,
            countryCode: "SE",
            password: "example_secret_token",
            method: "2022-blake3-aes-128-gcm"
        )

        self.servers = [node1, node2, node3, node4]
        self.selectedNodeId = node1.id
        saveServers()
    }
}
