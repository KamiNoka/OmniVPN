import Foundation

public enum ProxyProtocol: String, Codable, CaseIterable, Identifiable {
    case vless = "VLESS"
    case hysteria2 = "Hysteria 2"
    case wireguard = "WireGuard"
    case shadowsocks = "Shadowsocks"
    case trojan = "Trojan"
    case vmess = "VMess"
    case tuic = "TUIC"
    case ssh = "SSH"
    case direct = "Direct"

    public var id: String { rawValue }

    public var badgeColor: String {
        switch self {
        case .vless: return "purple"
        case .hysteria2: return "orange"
        case .wireguard: return "red"
        case .shadowsocks: return "blue"
        case .trojan: return "cyan"
        case .vmess: return "green"
        case .tuic: return "pink"
        case .ssh: return "gray"
        case .direct: return "secondary"
        }
    }

    public var defaultPort: Int {
        switch self {
        case .vless: return 443
        case .hysteria2: return 443
        case .wireguard: return 51820
        case .shadowsocks: return 8388
        case .trojan: return 443
        case .vmess: return 443
        case .tuic: return 443
        case .ssh: return 22
        case .direct: return 0
        }
    }
}

public struct ServerNode: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var server: String
    public var port: Int
    public var protocolType: ProxyProtocol
    public var countryCode: String?
    
    // Auth & Transport
    public var uuid: String?          // For VLESS / VMess
    public var password: String?      // For Shadowsocks / Trojan / Hysteria2
    public var method: String?        // For Shadowsocks (e.g. 2022-blake3-aes-128-gcm)
    public var network: String?       // tcp, ws, grpc, quic
    public var path: String?          // ws path or grpc serviceName
    public var host: String?          // HTTP Host or SNI

    // TLS & Reality
    public var tlsEnabled: Bool
    public var sni: String?
    public var allowInsecure: Bool
    public var fingerprint: String?   // chrome, safari, ios, random
    public var realityPublicKey: String?
    public var realityShortId: String?

    // WireGuard specific
    public var privateKey: String?
    public var peerPublicKey: String?
    public var presharedKey: String?
    public var localAddress: String?
    public var mtu: Int?

    // Hysteria 2 / TUIC specific
    public var upMbps: Int?
    public var downMbps: Int?
    public var obfsPassword: String?

    // Runtime state
    public var pingMs: Int?
    public var lastTested: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        server: String,
        port: Int,
        protocolType: ProxyProtocol,
        countryCode: String? = nil,
        uuid: String? = nil,
        password: String? = nil,
        method: String? = nil,
        network: String? = "tcp",
        path: String? = nil,
        host: String? = nil,
        tlsEnabled: Bool = false,
        sni: String? = nil,
        allowInsecure: Bool = false,
        fingerprint: String? = nil,
        realityPublicKey: String? = nil,
        realityShortId: String? = nil,
        privateKey: String? = nil,
        peerPublicKey: String? = nil,
        presharedKey: String? = nil,
        localAddress: String? = nil,
        mtu: Int? = 1420,
        upMbps: Int? = nil,
        downMbps: Int? = nil,
        obfsPassword: String? = nil,
        pingMs: Int? = nil,
        lastTested: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.server = server
        self.port = port
        self.protocolType = protocolType
        self.countryCode = countryCode
        self.uuid = uuid
        self.password = password
        self.method = method
        self.network = network
        self.path = path
        self.host = host
        self.tlsEnabled = tlsEnabled
        self.sni = sni
        self.allowInsecure = allowInsecure
        self.fingerprint = fingerprint
        self.realityPublicKey = realityPublicKey
        self.realityShortId = realityShortId
        self.privateKey = privateKey
        self.peerPublicKey = peerPublicKey
        self.presharedKey = presharedKey
        self.localAddress = localAddress
        self.mtu = mtu
        self.upMbps = upMbps
        self.downMbps = downMbps
        self.obfsPassword = obfsPassword
        self.pingMs = pingMs
        self.lastTested = lastTested
    }

    public var countryFlag: String {
        guard let countryCode = countryCode, countryCode.count == 2 else { return "🌐" }
        let base : UInt32 = 127397
        var flag = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let flagScalar = UnicodeScalar(base + scalar.value) {
                flag.append(String(flagScalar))
            }
        }
        return flag.isEmpty ? "🌐" : flag
    }
}
