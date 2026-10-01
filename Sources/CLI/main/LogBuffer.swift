import Foundation
import Logging

final class LogBuffer: @unchecked Sendable {
    struct Entry: Sendable {
        let label: String
        let event: LogEvent
    }

    private let lock = NSLock()
    private var storedEntries: [Entry] = []

    var entries: [Entry] {
        lock.withLock { storedEntries }
    }

    func handler(label: String) -> any LogHandler {
        BufferLogHandler(buffer: self, label: label)
    }

    private func append(_ entry: Entry) {
        lock.withLock { storedEntries.append(entry) }
    }

    private struct BufferLogHandler: LogHandler {
        let buffer: LogBuffer
        let label: String
        var logLevel: Logger.Level = .info
        var metadata: Logger.Metadata = [:]

        subscript(metadataKey key: String) -> Logger.Metadata.Value? {
            get { metadata[key] }
            set { metadata[key] = newValue }
        }

        func log(event: LogEvent) {
            buffer.append(Entry(label: label, event: event))
        }
    }
}
