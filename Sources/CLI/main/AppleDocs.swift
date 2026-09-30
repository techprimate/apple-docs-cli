import ArgumentParser
import Logging

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

@main
enum AppleDocs {
    private static let logger = Logger(label: "com.techprimate.apple-docs")

    @MainActor
    static func main() async {
        let telemetry = Dependencies.shared.telemetry
        telemetry.start()
        // Ignore SIGPIPE so writing to a closed pipe (e.g. `apple-docs ... | head`)
        // fails with EPIPE instead of terminating the process.
        // Must stay after `telemetry.start()`: the crash handler installs its own
        // SIGPIPE handler during start, which would otherwise replace SIG_IGN.
        signal(SIGPIPE, SIG_IGN)
        var loggingConfigured = false

        do {
            var command = try await CLI.asyncParseAsRoot()
            LoggingConfiguration.bootstrap(
                verbose: verboseLoggingEnabled(for: command),
                telemetry: telemetry
            )
            loggingConfigured = true
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
        (command as? any GlobalOptionsProviding)?.global.verbose ?? false
    }
}
