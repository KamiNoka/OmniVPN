import Foundation

public enum RoutingMode: String, Codable, CaseIterable, Identifiable {
    case ruleBased = "По правилам"
    case globalProxy = "Весь трафик (Global)"
    case direct = "Напрямую (Direct)"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .ruleBased:
            return "Использовать прокси только для заблокированных и зарубежных ресурсов, пропуская локальные напрямую."
        case .globalProxy:
            return "Весь интернет-трафик направляется через выбранный сервер."
        case .direct:
            return "Весь трафик идет напрямую без участия прокси-сервера."
        }
    }
}

public struct CustomRouteRule: Identifiable, Codable, Hashable {
    public var id: UUID
    public var domainKeywords: [String]
    public var ipRanges: [String]
    public var targetOutbound: String // "proxy", "direct", "block"
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        domainKeywords: [String] = [],
        ipRanges: [String] = [],
        targetOutbound: String = "direct",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.domainKeywords = domainKeywords
        self.ipRanges = ipRanges
        self.targetOutbound = targetOutbound
        self.isEnabled = isEnabled
    }
}
