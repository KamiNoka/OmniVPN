import Foundation

public struct Subscription: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var url: String
    public var lastUpdated: Date?
    public var autoUpdateHours: Int
    public var totalBytes: Int64?
    public var usedBytes: Int64?
    public var expireDate: Date?
    public var nodes: [ServerNode]

    public init(
        id: UUID = UUID(),
        name: String,
        url: String,
        lastUpdated: Date? = nil,
        autoUpdateHours: Int = 24,
        totalBytes: Int64? = nil,
        usedBytes: Int64? = nil,
        expireDate: Date? = nil,
        nodes: [ServerNode] = []
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.lastUpdated = lastUpdated
        self.autoUpdateHours = autoUpdateHours
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.expireDate = expireDate
        self.nodes = nodes
    }
}
