import ArgumentParser
import Foundation
import Logging

@main
enum AppleDocs {
    private static let logger = Logger(label: "com.techprimate.apple-docs")
    private static let telemetry = DefaultTelemetry(
        // Telemetry starts before SwiftLog is bootstrapped. Resolve its logger only when logging an event.
        logger: { Logger(label: "com.techprimate.apple-docs.telemetry") },
        environment: ProcessInfo.processInfo.environment
    )
    static let dependencies = Dependencies(telemetry: telemetry)

    @MainActor
    static func main() async {
        let telemetry = Self.telemetry
        telemetry.start()
        // Telemetry installs a SIGPIPE handler during start, so configure the terminal afterward.
        TerminalSetup().configure()
        var loggingConfigured = false

        do {
            var command = try await CLI.asyncParseAsRoot()
            LoggingConfiguration.bootstrap(
                verbose: verboseLoggingEnabled(for: command),
                telemetry: telemetry
            )
            loggingConfigured = true
            // Construct command dependencies only after their log handlers are installed.
            _ = Self.dependencies
            Self.logger.debug("CLI command parsed")
            if var asyncCommand = command as? any AsyncParsableCommand {
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
        guard let optionsProvider = command as? any GlobalOptionsProviding else {
            return false
        }
        return optionsProvider.global.verbose
    }
}
