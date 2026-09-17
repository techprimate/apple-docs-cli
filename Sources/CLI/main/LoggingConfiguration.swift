import Logging

enum LoggingConfiguration {
    static func bootstrap(verbose: Bool, telemetry: Telemetry, sessionLogBuffer: SessionLogBuffer? = nil) {
        LoggingSystem.bootstrap { label in
            handler(
                console: StreamLogHandler.standardError(label: label),
                telemetry: telemetry.makeLogHandler(),
                verbose: verbose,
                sessionLogBuffer: sessionLogBuffer,
                label: label
            )
        }
    }

    static func handler(
        console: any LogHandler, telemetry: (any LogHandler)?, verbose: Bool,
        sessionLogBuffer: SessionLogBuffer? = nil, label: String = "apple-docs"
    ) -> any LogHandler {
        var handlers: [any LogHandler] = []
        if let sessionLogBuffer {
            var session = SessionLogHandler(buffer: sessionLogBuffer, label: label)
            session.logLevel = verbose ? .debug : .warning
            handlers.append(session)
        } else if verbose {
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
