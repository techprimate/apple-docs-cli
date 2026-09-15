import Logging

#if canImport(SentrySwift)
    import SentrySwiftLog
#endif

enum LoggingConfiguration {
    static func bootstrap(verbose: Bool, telemetryEnabled: Bool) {
        LoggingSystem.bootstrap { label in
            var telemetry: (any LogHandler)?
            #if canImport(SentrySwift)
                if telemetryEnabled {
                    telemetry = SentryLogHandler(logLevel: .info)
                }
            #endif
            return handler(
                console: StreamLogHandler.standardError(label: label),
                telemetry: telemetry,
                verbose: verbose
            )
        }
    }

    static func handler(
        console: any LogHandler, telemetry: (any LogHandler)?, verbose: Bool
    ) -> any LogHandler {
        var handlers: [any LogHandler] = []
        if verbose {
            var console = console
            console.logLevel = .debug
            handlers.append(console)
        }
        if var telemetry {
            telemetry.logLevel = .info
            handlers.append(telemetry)
        }
        guard !handlers.isEmpty else { return SwiftLogNoOpLogHandler() }
        return MultiplexLogHandler(handlers)
    }
}
