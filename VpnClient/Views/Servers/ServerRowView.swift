import SwiftUI

public struct ServerRowView: View {
    public let node: ServerNode
    public let isSelected: Bool
    public let onSelect: () -> Void

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Text(node.countryFlag)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 4) {
                    Text(node.name)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(node.protocolType.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(protocolBadgeColor.opacity(0.12))
                            .foregroundColor(protocolBadgeColor)
                            .clipShape(Capsule())

                        Text("\(node.server):\(node.port)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Ping Badge
                if let ping = node.pingMs {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(pingColor(ping))
                            .frame(width: 6, height: 6)

                        Text("\(ping) ms")
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundColor(pingColor(ping))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(pingColor(ping).opacity(0.1))
                    .clipShape(Capsule())
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func pingColor(_ ms: Int) -> Color {
        if ms < 100 { return .green }
        if ms < 250 { return .orange }
        return .red
    }

    private var protocolBadgeColor: Color {
        switch node.protocolType {
        case .vless: return .purple
        case .hysteria2: return .orange
        case .wireguard: return .red
        case .shadowsocks: return .blue
        case .trojan: return .cyan
        case .vmess: return .green
        case .tuic: return .pink
        case .ssh: return .gray
        case .direct: return .secondary
        }
    }
}
