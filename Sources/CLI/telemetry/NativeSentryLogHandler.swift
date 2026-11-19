#if os(Linux)
    import Logging
    import SentryNative

    struct NativeSentryLogHandler: LogHandler {
        var logLevel: Logger.Level = .info
        var metadata: Logger.Metadata = [:]
        var metadataProvider: Logger.MetadataProvider?

        subscript(metadataKey key: String) -> Logger.Metadata.Value? {
            get { metadata[key] }
            set { metadata[key] = newValue }
        }

        func log(event: LogEvent) {
            var combined = metadata
            combined.merge(metadataProvider?.get() ?? [:]) { _, value in value }
            combined.merge(event.metadata ?? [:]) { _, value in value }
            var attributes = Dictionary(
                uniqueKeysWithValues: combined.map { key, value in
                    ("swift-log.\(key)", value.description)
                })
            attributes["swift-log.level"] = event.level.rawValue
            _ = sentry_log(level(event.level), event.message.description, NativeSentryValue.attributes(attributes))
        }

        private func level(_ level: Logger.Level) -> sentry_level_t {
            switch level {
            case .trace: SENTRY_LEVEL_TRACE
            case .debug: SENTRY_LEVEL_DEBUG
            case .info, .notice: SENTRY_LEVEL_INFO
            case .warning: SENTRY_LEVEL_WARNING
            case .error: SENTRY_LEVEL_ERROR
            case .critical: SENTRY_LEVEL_FATAL
            }
        }
    }
#endif
