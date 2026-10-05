import Foundation

public class SubscriptionParser {
    public static let shared = SubscriptionParser()

    public init() {}

    public func parse(content: String) -> [ServerNode] {
        var trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Try Base64 decoding if the whole text is base64 (common in V2Ray/Shadowsocks subscription feeds)
        if !trimmed.contains("outbounds") && !trimmed.contains("proxies:") && !trimmed.hasPrefix("{") {
            if let decodedData = Data(base64Encoded: trimmed, options: [.ignoreUnknownCharacters]),
               let decodedString = String(data: decodedData, encoding: .utf8),
               !decodedString.isEmpty {
                trimmed = decodedString.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 2. Check if JSON (Sing-box config)
        if trimmed.hasPrefix("{") {
            if let nodes = parseSingBoxJSON(trimmed), !nodes.isEmpty {
                return nodes
            }
        }

        // 3. Check if YAML (Clash config)
        if trimmed.contains("proxies:") {
            if let nodes = parseClashProxies(trimmed), !nodes.isEmpty {
                return nodes
            }
        }

        // 4. Parse line-by-line URI schemes
        var nodes: [ServerNode] = []
        let lines = trimmed.components(separatedBy: .newlines)
        for line in lines {
            let lineTrimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !lineTrimmed.isEmpty, !lineTrimmed.hasPrefix("//"), !lineTrimmed.hasPrefix("#") else { continue }
            if let node = parseURI(lineTrimmed) {
                nodes.append(node)
            }
        }

        return nodes
    }

    // MARK: - URI Parsing

    public func parseURI(_ uriString: String) -> ServerNode? {
        guard let url = URL(string: uriString) else { return nil }
        let scheme = url.scheme?.lowercased() ?? ""

        switch scheme {
        case "vless":
            return parseVLESS(url)
        case "hysteria2", "hy2":
            return parseHysteria2(url)
        case "trojan":
            return parseTrojan(url)
        case "ss":
            return parseShadowsocks(url, raw: uriString)
        case "vmess":
            return parseVMess(uriString)
        case "tuic":
            return parseTUIC(url)
        default:
            return nil
        }
    }

    // MARK: - VLESS
    // Example: vless://uuid@host:port?security=reality&sni=example.com&pbk=xxx&sid=yyy&type=grpc&serviceName=zzz#Tag
    private func parseVLESS(_ url: URL) -> ServerNode? {
        guard let host = url.host, let port = url.port ?? (url.scheme == "vless" ? 443 : nil) else { return nil }
        let uuid = url.user ?? ""
        let fragment = url.fragment?.removingPercentEncoding ?? "VLESS-\(host)"

        var queryItems: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = components.queryItems {
            for item in items {
                queryItems[item.name.lowercased()] = item.value
            }
        }

        let security = queryItems["security"] ?? "none"
        let isReality = security == "reality"
        let isTLS = isReality || security == "tls"
        let sni = queryItems["sni"] ?? queryItems["host"]
        let pbk = queryItems["pbk"] ?? queryItems["publickey"]
        let sid = queryItems["sid"] ?? queryItems["shortid"]
        let fp = queryItems["fp"] ?? queryItems["fingerprint"] ?? "chrome"
        let network = queryItems["type"] ?? "tcp"
        let path = queryItems["path"] ?? queryItems["servicename"]

        return ServerNode(
            name: fragment,
            server: host,
            port: port,
            protocolType: .vless,
            uuid: uuid,
            network: network,
            path: path,
            host: sni,
            tlsEnabled: isTLS,
            sni: sni,
            fingerprint: fp,
            realityPublicKey: pbk,
            realityShortId: sid
        )
    }

    // MARK: - Hysteria 2
    // Example: hysteria2://password@host:port?sni=example.com&obfs=password#Tag
    private func parseHysteria2(_ url: URL) -> ServerNode? {
        guard let host = url.host, let port = url.port ?? 443 else { return nil }
        let password = url.user ?? ""
        let fragment = url.fragment?.removingPercentEncoding ?? "Hy2-\(host)"

        var queryItems: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = components.queryItems {
            for item in items {
                queryItems[item.name.lowercased()] = item.value
            }
        }

        let sni = queryItems["sni"] ?? host
        let obfsPassword = queryItems["obfs-password"] ?? queryItems["obfs"]
        let insecure = (queryItems["insecure"] == "1")

        return ServerNode(
            name: fragment,
            server: host,
            port: port,
            protocolType: .hysteria2,
            password: password,
            tlsEnabled: true,
            sni: sni,
            allowInsecure: insecure,
            obfsPassword: obfsPassword
        )
    }

    // MARK: - Trojan
    private func parseTrojan(_ url: URL) -> ServerNode? {
        guard let host = url.host, let port = url.port ?? 443 else { return nil }
        let password = url.user ?? ""
        let fragment = url.fragment?.removingPercentEncoding ?? "Trojan-\(host)"

        var queryItems: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = components.queryItems {
            for item in items {
                queryItems[item.name.lowercased()] = item.value
            }
        }

        let sni = queryItems["sni"] ?? queryItems["peer"] ?? host
        let network = queryItems["type"] ?? "tcp"

        return ServerNode(
            name: fragment,
            server: host,
            port: port,
            protocolType: .trojan,
            password: password,
            network: network,
            tlsEnabled: true,
            sni: sni
        )
    }

    // MARK: - Shadowsocks (SIP002)
    // ss://BASE64(method:password)@host:port#Tag
    private func parseShadowsocks(_ url: URL, raw: String) -> ServerNode? {
        guard let host = url.host, let port = url.port else { return nil }
        let fragment = url.fragment?.removingPercentEncoding ?? "SS-\(host)"

        var method = "chacha20-ietf-poly1305"
        var password = ""

        if let userInfo = url.user {
            // Check if user info is base64 encoded
            if let decodedData = Data(base64Encoded: userInfo), let decoded = String(data: decodedData, encoding: .utf8) {
                let parts = decoded.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    method = parts[0]
                    password = parts[1]
                }
            } else if let pass = url.password {
                method = userInfo
                password = pass
            }
        }

        return ServerNode(
            name: fragment,
            server: host,
            port: port,
            protocolType: .shadowsocks,
            password: password,
            method: method
        )
    }

    // MARK: - VMess
    // vmess://BASE64(JSON)
    private func parseVMess(_ raw: String) -> ServerNode? {
        guard raw.hasPrefix("vmess://") else { return nil }
        let base64Part = String(raw.dropFirst(8))
        guard let data = Data(base64Encoded: base64Part, options: [.ignoreUnknownCharacters]),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let name = (json["ps"] as? String) ?? "VMess"
        let host = (json["add"] as? String) ?? ""
        let portInt = (json["port"] as? Int) ?? Int((json["port"] as? String) ?? "443") ?? 443
        let uuid = (json["id"] as? String) ?? ""
        let net = (json["net"] as? String) ?? "tcp"
        let path = json["path"] as? String
        let sni = json["sni"] as? String ?? (json["host"] as? String)
        let tls = (json["tls"] as? String) == "tls"

        return ServerNode(
            name: name,
            server: host,
            port: portInt,
            protocolType: .vmess,
            uuid: uuid,
            network: net,
            path: path,
            tlsEnabled: tls,
            sni: sni
        )
    }

    // MARK: - TUIC
    private func parseTUIC(_ url: URL) -> ServerNode? {
        guard let host = url.host, let port = url.port ?? 443 else { return nil }
        let token = url.user ?? ""
        let fragment = url.fragment?.removingPercentEncoding ?? "TUIC-\(host)"

        return ServerNode(
            name: fragment,
            server: host,
            port: port,
            protocolType: .tuic,
            password: token,
            tlsEnabled: true,
            sni: host
        )
    }

    // MARK: - Sing-box JSON Outbounds
    private func parseSingBoxJSON(_ jsonString: String) -> [ServerNode]? {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outbounds = root["outbounds"] as? [[String: Any]] else {
            return nil
        }

        var nodes: [ServerNode] = []
        for item in outbounds {
            guard let typeStr = item["type"] as? String,
                  let tag = item["tag"] as? String,
                  let server = item["server"] as? String,
                  let port = item["server_port"] as? Int else {
                continue
            }

            var proto: ProxyProtocol?
            switch typeStr.lowercased() {
            case "vless": proto = .vless
            case "hysteria2": proto = .hysteria2
            case "wireguard": proto = .wireguard
            case "shadowsocks": proto = .shadowsocks
            case "trojan": proto = .trojan
            case "vmess": proto = .vmess
            case "tuic": proto = .tuic
            default: break
            }

            guard let validProto = proto else { continue }

            var node = ServerNode(
                name: tag,
                server: server,
                port: port,
                protocolType: validProto
            )

            if let uuid = item["uuid"] as? String { node.uuid = uuid }
            if let password = item["password"] as? String { node.password = password }
            if let method = item["method"] as? String { node.method = method }

            if let tls = item["tls"] as? [String: Any] {
                node.tlsEnabled = (tls["enabled"] as? Bool) ?? true
                node.sni = tls["server_name"] as? String
                if let reality = tls["reality"] as? [String: Any] {
                    node.realityPublicKey = reality["public_key"] as? String
                    node.realityShortId = reality["short_id"] as? String
                }
            }

            nodes.append(node)
        }
        return nodes
    }

    // MARK: - Clash YAML Proxies
    private func parseClashProxies(_ yamlString: String) -> [ServerNode]? {
        // Simple regex/line parser for Clash proxies section
        var nodes: [ServerNode] = []
        let lines = yamlString.components(separatedBy: .newlines)
        var insideProxies = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("proxies:") {
                insideProxies = true
                continue
            }
            if insideProxies {
                if !line.hasPrefix(" ") && !line.hasPrefix("\t") && !line.isEmpty {
                    break // Exited proxies block
                }
                // Check if inline dictionary
                if trimmed.hasPrefix("- {") && trimmed.hasSuffix("}") {
                    let content = String(trimmed.dropFirst(3).dropLast(1))
                    if let node = parseClashDictLine(content) {
                        nodes.append(node)
                    }
                }
            }
        }
        return nodes
    }

    private func parseClashDictLine(_ line: String) -> ServerNode? {
        let pairs = line.components(separatedBy: ",")
        var dict: [String: String] = [:]
        for pair in pairs {
            let kv = pair.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") }
            if kv.count == 2 {
                dict[kv[0]] = kv[1]
            }
        }

        guard let name = dict["name"], let server = dict["server"], let portStr = dict["port"], let port = Int(portStr), let type = dict["type"] else {
            return nil
        }

        var proto: ProxyProtocol = .shadowsocks
        switch type.lowercased() {
        case "vless": proto = .vless
        case "hysteria2": proto = .hysteria2
        case "wireguard": proto = .wireguard
        case "trojan": proto = .trojan
        case "vmess": proto = .vmess
        case "ss": proto = .shadowsocks
        default: return nil
        }

        return ServerNode(
            name: name,
            server: server,
            port: port,
            protocolType: proto,
            uuid: dict["uuid"],
            password: dict["password"],
            method: dict["cipher"],
            tlsEnabled: dict["tls"] == "true",
            sni: dict["sni"] ?? dict["servername"]
        )
    }
}
