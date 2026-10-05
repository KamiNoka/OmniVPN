import Foundation
import Network

final class PingState: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResponded = false

    func complete(handler: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        if !hasResponded {
            hasResponded = true
            handler()
        }
    }
}

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
            let state = PingState()

            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + timeoutSeconds)
            timer.setEventHandler {
                state.complete {
                    connection.cancel()
                    continuation.resume(returning: nil)
                }
            }
            timer.resume()

            connection.stateUpdateHandler = { connState in
                switch connState {
                case .ready:
                    state.complete {
                        timer.cancel()
                        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                        connection.cancel()
                        continuation.resume(returning: max(1, elapsedMs))
                    }
                case .failed, .cancelled:
                    state.complete {
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
