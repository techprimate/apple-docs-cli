import Logging

#if DEBUG
    protocol Telemetry: Sendable {
        func start()
        func startCommand(_ context: TelemetryCommandContext)
        func record(_ metric: TelemetryMetric, context: TelemetryCommandContext)
        func finishCommand(error: (any Error)?)
        func makeLogHandler() -> (any LogHandler)?
    }

    extension NoOpTelemetry: Telemetry {}
    #if canImport(SentrySwift)
        extension SentryTelemetry: Telemetry {}
    #endif
#else
    typealias Telemetry = DefaultTelemetry
#endif

#if canImport(SentrySwift)
    typealias DefaultTelemetry = SentryTelemetry
#else
    typealias DefaultTelemetry = NoOpTelemetry
#endif

enum TelemetryMetric: Sendable {
    case technologyCatalog(count: Int)
    case typeCatalog(count: Int)
    case typeSearch(matches: Int)
    case typeView(responseBytes: Int)
}
