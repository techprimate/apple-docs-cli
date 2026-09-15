import ArgumentParser
import Foundation
import Logging

#if canImport(SentrySwift)
    @preconcurrency import SentrySwift
#endif

@main
enum AppleDocs {
    private static let logger = Logger(label: "com.techprimate.apple-docs")

    @MainActor
    static func main() async {
        let telemetryEnabled = configureTelemetry()
        var loggingConfigured = false

        do {
            var command = try await CLI.asyncParseAsRoot()
            LoggingConfiguration.bootstrap(
                verbose: verboseLoggingEnabled(for: command),
                telemetryEnabled: telemetryEnabled
            )
            loggingConfigured = true
            Self.logger.debug("CLI command parsed")
            if var asyncCommand = command as? any AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
            Self.logger.debug("CLI command finished")
            finishTelemetry(enabled: telemetryEnabled)
        } catch {
            if !loggingConfigured {
                LoggingConfiguration.bootstrap(verbose: false, telemetryEnabled: telemetryEnabled)
            }
            captureTelemetry(error, enabled: telemetryEnabled)
            CLI.exit(withError: error)
        }
    }

    private static func verboseLoggingEnabled(for command: any ParsableCommand) -> Bool {
        (command as? any GlobalOptionsProviding)?.global.verbose ?? false
    }

    private static func configureTelemetry() -> Bool {
        #if canImport(SentrySwift)
            let enabled = SentryConfiguration.isEnabled(
                environment: ProcessInfo.processInfo.environment
            )
            if enabled {
                SentrySDK.start { options in
                    SentryConfiguration.configure(options)
                }
            }
            return enabled
        #else
            return false
        #endif
    }

    private static func finishTelemetry(enabled: Bool) {
        #if canImport(SentrySwift)
            guard enabled else {
                return
            }
            SentrySDK.span?.status = .ok
            Self.logger.info("CLI command completed")
            SentrySDK.span?.finish()
            SentrySDK.flush(timeout: 2)
        #endif
    }

    private static func captureTelemetry(_ error: Error, enabled: Bool) {
        #if canImport(SentrySwift)
            guard enabled else {
                return
            }
            if let span = SentrySDK.span {
                // Lookup misses are actionable CLI outcomes, not application reliability failures.
                let expected = error is ValidationError || SentryConfiguration.isExpected(error: error)
                span.status = expected ? .invalidArgument : .internalError
                if expected {
                    Self.logger.info("CLI command rejected")
                } else {
                    Self.logger.error("CLI command failed")
                    SentrySDK.capture(error: error)
                }
                span.finish()
            }
            SentrySDK.flush(timeout: 2)
        #endif
    }
}
