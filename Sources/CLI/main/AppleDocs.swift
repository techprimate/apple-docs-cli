import ArgumentParser
import Logging

@main
enum AppleDocs {
    private static let logger = Logger(label: "com.techprimate.apple-docs")

    @MainActor
    static func main() async {
        let telemetry = Dependencies.telemetry
        telemetry.start()
        var loggingConfigured = false

        do {
            var command = try await CLI.asyncParseAsRoot()
            let mode = TerminalCapabilities.current.mode(for: command)
            let logs = mode == .interactive ? SessionLogBuffer() : nil
            LoggingConfiguration.bootstrap(
                verbose: verboseLoggingEnabled(for: command),
                telemetry: telemetry,
                sessionLogBuffer: logs
            )
            loggingConfigured = true
            Self.logger.debug("CLI command parsed")
            if let documentation = command as? any DocumentationCommand, let mode {
                try await documentation.run(mode: mode, logs: logs, telemetry: telemetry)
            } else if var asyncCommand = command as? any AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
            Self.logger.debug("CLI command finished")
            telemetry.finishCommand(error: nil)
        } catch {
            if !loggingConfigured {
                LoggingConfiguration.bootstrap(verbose: false, telemetry: telemetry)
            }
            telemetry.finishCommand(error: error)
            CLI.exit(withError: error)
        }
    }

    private static func verboseLoggingEnabled(for command: any ParsableCommand) -> Bool {
        (command as? any GlobalOptionsProviding)?.global.verbose ?? false
    }
}
