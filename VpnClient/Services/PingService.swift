import Foundation
import Network

public class PingService {
    public static let shared = PingService()

    public init() {}

    /// Tests TCP connection latency to the node's server and port in milliseconds
    public func ping(node: ServerNode, timeoutSeconds: Double = 2.5) async -> Int? {
        let startTime = CFAbsoluteTimeGetCurrent()
        let host = NWEndpoint.Host(node.server)
        guard let port = NWEndpoint.Port(rawValue: UInt16(node.port)) else { return nil }

        let parameters: NWParameters = .tcp
        parameters.preferNoProxies = true

        let connection = NWConnection(host: host, port: port, using: parameters)

        return await withCheckedContinuation { continuation in
            var hasResponded = false

            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + timeoutSeconds)
            timer.setEventHandler {
                if !hasResponded {
                    hasResponded = true
                    connection.cancel()
                    continuation.resume(returning: nil)
                }
            }
            timer.resume()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !hasResponded {
                        hasResponded = true
                        timer.cancel()
                        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                        connection.cancel()
                        continuation.resume(returning: max(1, elapsedMs))
                    }
                case .failed, .cancelled:
                    if !hasResponded {
                        hasResponded = true
                        timer.cancel()
                        continuation.resume(returning: nil)
                    }
                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    /// Pings all nodes concurrently with a throttle
    public func pingAll(nodes: [ServerNode]) async -> [UUID: Int?] {
        await withTaskGroup(of: (UUID, Int?).self) { group in
            for node in nodes {
                group.addTask {
                    let pingResult = await self.ping(node: node)
                    return (node.id, pingResult)
                }
            }

            var results: [UUID: Int?] = [:]
            for await (id, ping) in group {
                results[id] = ping
            }
            return results
        }
    }
}
