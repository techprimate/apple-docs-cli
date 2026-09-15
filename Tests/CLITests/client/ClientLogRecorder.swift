import Logging
import Synchronization

@available(macOS 15, *)
final class ClientLogRecorder: Sendable {
    private let storage = Mutex<[LogEvent]>([])

    var events: [LogEvent] {
        storage.withLock { $0 }
    }

    func logger() -> Logger {
        Logger(label: "test.client") { _ in
            RecordingHandler(recorder: self)
        }
    }

    private func append(_ event: LogEvent) {
        storage.withLock { $0.append(event) }
    }

    private struct RecordingHandler: LogHandler {
        let recorder: ClientLogRecorder
        var logLevel: Logger.Level = .trace
        var metadata: Logger.Metadata = [:]

        subscript(metadataKey key: String) -> Logger.Metadata.Value? {
            get { metadata[key] }
            set { metadata[key] = newValue }
        }

        func log(event: LogEvent) {
            recorder.append(event)
        }
    }
}
