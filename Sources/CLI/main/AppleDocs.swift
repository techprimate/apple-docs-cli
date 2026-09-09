import ArgumentParser
import Foundation
import Logging
@preconcurrency import SentrySwift
import SentrySwiftLog

@main
enum AppleDocs {
    private static let logger = Logger(label: "com.techprimate.apple-docs")

    @MainActor
    static func main() async {
        let telemetryEnabled = SentryConfiguration.isEnabled(
            environment: ProcessInfo.processInfo.environment
        )
        if telemetryEnabled {
            SentrySDK.start { options in
                SentryConfiguration.configure(options)
            }
            LoggingSystem.bootstrap { _ in
                SentryLogHandler(logLevel: .info)
            }
        } else {
            LoggingSystem.bootstrap { _ in
                SwiftLogNoOpLogHandler()
            }
        }

        do {
            var command = try await CLI.asyncParseAsRoot()
            if var asyncCommand = command as? any AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
            if telemetryEnabled {
                SentrySDK.span?.status = .ok
                Self.logger.info("CLI command completed")
                SentrySDK.span?.finish()
                SentrySDK.flush(timeout: 2)
            }
        } catch {
            if telemetryEnabled, let span = SentrySDK.span {
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
            if telemetryEnabled {
                SentrySDK.flush(timeout: 2)
            }
            CLI.exit(withError: error)
        }
    }
}
