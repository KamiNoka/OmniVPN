import Foundation

public class ConfigBuilder {
    public static let shared = ConfigBuilder()

    public init() {}

    public func buildConfigJSON(
        selectedNode: ServerNode,
        routingMode: RoutingMode = .ruleBased,
        customRules: [CustomRouteRule] = [],
        dnsServer: String = "https://1.1.1.1/dns-query"
    ) -> String? {
        var root: [String: Any] = [:]

        // 1. Log configuration
        root["log"] = [
            "disabled": false,
            "level": "warn",
            "timestamp": true
        ]

        // 2. DNS configuration
        root["dns"] = [
            "servers": [
                [
                    "tag": "remote-dns",
                    "address": dnsServer,
                    "detour": "proxy"
                ],
                [
                    "tag": "local-dns",
                    "address": "local",
                    "detour": "direct"
                ]
            ],
            "rules": [
                [
                    "outbound": "any",
                    "server": "local-dns"
                ],
                [
                    "rule_set": "geosite-ru",
                    "server": "local-dns"
                ]
            ],
            "strategy": "prefer_ipv4"
        ]

        // 3. Inbounds (Virtual TUN device for iOS PacketTunnel)
        root["inbounds"] = [
            [
                "type": "tun",
                "tag": "tun-in",
                "interface_name": "utun",
                "inet4_address": "172.19.0.1/30",
                "auto_route": true,
                "strict_route": true,
                "stack": "mixed",
                "sniff": true,
                "sniff_override_destination": false
            ]
        ]

        // 4. Outbounds
        var outbounds: [[String: Any]] = []

        // Primary Proxy Outbound
        if let proxyOutbound = buildOutbound(from: selectedNode) {
            outbounds.append(proxyOutbound)
        }

        // Direct Outbound
        outbounds.append([
            "type": "direct",
            "tag": "direct"
        ])

        // Block Outbound
        outbounds.append([
            "type": "block",
            "tag": "block"
        ])

        // DNS Outbound
        outbounds.append([
            "type": "dns",
            "tag": "dns-out"
        ])

        root["outbounds"] = outbounds

        // 5. Routing Rules
        var rules: [[String: Any]] = []

        // Hijack DNS
        rules.append([
            "protocol": "dns",
            "outbound": "dns-out"
        ])

        // Private / LAN IPs bypass
        rules.append([
            "ip_is_private": true,
            "outbound": "direct"
        ])

        if routingMode == .ruleBased {
            // Bypass Russian domains & IPs if rule-based
            rules.append([
                "rule_set": ["geosite-ru", "geoip-ru"],
                "outbound": "direct"
            ])
        }

        // User custom rules
        for custom in customRules where custom.isEnabled {
            var ruleDict: [String: Any] = [
                "outbound": custom.targetOutbound
            ]
            if !custom.domainKeywords.isEmpty {
                ruleDict["domain_keyword"] = custom.domainKeywords
            }
            if !custom.ipRanges.isEmpty {
                ruleDict["ip_cidr"] = custom.ipRanges
            }
            rules.append(ruleDict)
        }

        let finalOutbound = (routingMode == .direct) ? "direct" : "proxy"

        root["route"] = [
            "rules": rules,
            "final": finalOutbound,
            "auto_detect_interface": true
        ]

        // Serialize to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }

    // MARK: - Outbound Generator per Protocol

    private func buildOutbound(from node: ServerNode) -> [String: Any]? {
        var dict: [String: Any] = [
            "tag": "proxy"
        ]

        switch node.protocolType {
        case .vless:
            dict["type"] = "vless"
            dict["server"] = node.server
            dict["server_port"] = node.port
            dict["uuid"] = node.uuid ?? ""
            dict["flow"] = (node.realityPublicKey != nil) ? "xtls-rprx-vision" : ""

            if node.tlsEnabled {
                var tlsDict: [String: Any] = [
                    "enabled": true,
                    "server_name": node.sni ?? node.server,
                    "utls": [
                        "enabled": true,
                        "fingerprint": node.fingerprint ?? "chrome"
                    ]
                ]
                if let pbk = node.realityPublicKey, !pbk.isEmpty {
                    tlsDict["reality"] = [
                        "enabled": true,
                        "public_key": pbk,
                        "short_id": node.realityShortId ?? ""
                    ]
                }
                dict["tls"] = tlsDict
            }

            if let net = node.network, net == "ws" {
                dict["transport"] = [
                    "type": "ws",
                    "path": node.path ?? "/",
                    "headers": [
                        "Host": node.host ?? node.sni ?? node.server
                    ]
                ]
            } else if let net = node.network, net == "grpc" {
                dict["transport"] = [
                    "type": "grpc",
                    "service_name": node.path ?? ""
                ]
            }

        case .hysteria2:
            dict["type"] = "hysteria2"
            dict["server"] = node.server
            dict["server_port"] = node.port
            dict["password"] = node.password ?? ""
            if let obfs = node.obfsPassword, !obfs.isEmpty {
                dict["obfs"] = [
                    "type": "salamander",
                    "password": obfs
                ]
            }
            dict["tls"] = [
                "enabled": true,
                "server_name": node.sni ?? node.server,
                "insecure": node.allowInsecure
            ]

        case .shadowsocks:
            dict["type"] = "shadowsocks"
            dict["server"] = node.server
            dict["server_port"] = node.port
            dict["method"] = node.method ?? "chacha20-ietf-poly1305"
            dict["password"] = node.password ?? ""

        case .trojan:
            dict["type"] = "trojan"
            dict["server"] = node.server
            dict["server_port"] = node.port
            dict["password"] = node.password ?? ""
            dict["tls"] = [
                "enabled": true,
                "server_name": node.sni ?? node.server,
                "insecure": node.allowInsecure
            ]

        case .vmess:
            dict["type"] = "vmess"
            dict["server"] = node.server
            dict["server_port"] = node.port
            dict["uuid"] = node.uuid ?? ""
            dict["security"] = "auto"
            if node.tlsEnabled {
                dict["tls"] = [
                    "enabled": true,
                    "server_name": node.sni ?? node.server
                ]
            }

        case .wireguard:
            dict["type"] = "wireguard"
            dict["server"] = node.server
            dict["server_port"] = node.port
            dict["system_interface"] = false
            dict["local_address"] = [node.localAddress ?? "10.0.0.2/32"]
            dict["private_key"] = node.privateKey ?? ""
            dict["peer_public_key"] = node.peerPublicKey ?? ""
            if let psk = node.presharedKey, !psk.isEmpty {
                dict["pre_shared_key"] = psk
            }
            dict["mtu"] = node.mtu ?? 1420

        case .tuic:
            dict["type"] = "tuic"
            dict["server"] = node.server
            dict["server_port"] = node.port
            dict["uuid"] = node.uuid ?? UUID().uuidString
            dict["password"] = node.password ?? ""
            dict["congestion_control"] = "bbr"
            dict["tls"] = [
                "enabled": true,
                "server_name": node.sni ?? node.server
            ]

        case .ssh:
            dict["type"] = "ssh"
            dict["server"] = node.server
            dict["server_port"] = node.port
            dict["user"] = "root"
            dict["password"] = node.password ?? ""

        case .direct:
            return [
                "type": "direct",
                "tag": "proxy"
            ]
        }

        return dict
    }
}
