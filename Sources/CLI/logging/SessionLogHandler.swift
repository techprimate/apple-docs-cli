import Logging

struct SessionLogHandler: LogHandler {
    let buffer: SessionLogBuffer
    let label: String
    var logLevel: Logger.Level = .warning
    var metadata: Logger.Metadata = [:]
    var metadataProvider: Logger.MetadataProvider?

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        var combined = metadata
        combined.merge(metadataProvider?.get() ?? [:]) { _, provided in provided }
        combined.merge(event.metadata ?? [:]) { _, explicit in explicit }
        buffer.append(
            SessionLogEntry(
                level: event.level, label: label, message: event.message.description, metadata: combined
            ))
    }
}
