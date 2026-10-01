import Logging

enum LoggingConfiguration {
    static func bootstrap(verbose: Bool, telemetry: Telemetry, buffer: LogBuffer? = nil) {
        LoggingSystem.bootstrap { label in
            handler(
                console: buffer?.handler(label: label) ?? StreamLogHandler.standardError(label: label),
                telemetry: telemetry.makeLogHandler(),
                verbose: verbose,
                interactive: buffer != nil
            )
        }
    }

    static func handler(
        console: any LogHandler, telemetry: (any LogHandler)?, verbose: Bool, interactive: Bool = false
    ) -> any LogHandler {
        var handlers: [any LogHandler] = []
        if verbose || interactive {
            var console = console
            console.logLevel = verbose ? .debug : .info
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
