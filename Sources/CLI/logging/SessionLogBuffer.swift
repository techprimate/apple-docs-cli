import Foundation
import Logging
import Synchronization

struct SessionLogEntry: Equatable, Sendable {
    var id: UInt64 = 0
    var timestamp = Date()
    let level: Logger.Level
    let label: String
    let message: String
    var metadata: Logger.Metadata = [:]
}

final class SessionLogBuffer: Sendable {
    private struct State: Sendable {
        var entries: [SessionLogEntry] = []
        var nextID: UInt64 = 0
        var hasPendingChange = false
    }

    private let capacity: Int
    private let storage = Mutex(State())
    let changes: AsyncStream<UInt64>
    private let continuation: AsyncStream<UInt64>.Continuation

    init(capacity: Int = 500) {
        precondition(capacity > 0)
        self.capacity = capacity
        let signal = AsyncStream<UInt64>.makeStream(bufferingPolicy: .bufferingNewest(1))
        changes = signal.stream
        continuation = signal.continuation
    }

    deinit { continuation.finish() }

    func append(_ entry: SessionLogEntry) {
        let change: UInt64? = storage.withLock { state in
            state.nextID += 1
            var entry = entry
            entry.id = state.nextID
            state.entries.append(entry)
            if state.entries.count > capacity { state.entries.removeFirst(state.entries.count - capacity) }
            guard !state.hasPendingChange else { return nil }
            state.hasPendingChange = true
            return state.nextID
        }
        if let change { continuation.yield(change) }
    }

    func snapshot() -> [SessionLogEntry] {
        storage.withLock { state in
            // Reading acknowledges this burst so the next append can wake the renderer.
            state.hasPendingChange = false
            return state.entries
        }
    }
}
