import Logging

enum LoggingConfiguration {
    static func bootstrap(verbose: Bool, telemetry: Telemetry) {
        LoggingSystem.bootstrap { label in
            handler(
                console: StreamLogHandler.standardError(label: label),
                telemetry: telemetry.makeLogHandler(),
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
