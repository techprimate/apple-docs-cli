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

    protocol TelemetryProvider {
        associatedtype TelemetryType: Telemetry
        var telemetry: TelemetryType { get }
    }

    extension Dependencies: TelemetryProvider {}
#else
    typealias Telemetry = DefaultTelemetry
#endif

#if canImport(SentrySwift)
    typealias DefaultTelemetry = SentryTelemetry
#else
    typealias DefaultTelemetry = NoOpTelemetry
#endif
