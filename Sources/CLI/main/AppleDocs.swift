import ArgumentParser
import Foundation
import Logging

#if canImport(SentrySwift)
    @preconcurrency import SentrySwift
    import SentrySwiftLog
#endif

@main
enum AppleDocs {
    private static let logger = Logger(label: "com.techprimate.apple-docs")

    @MainActor
    static func main() async {
        let telemetryEnabled = configureTelemetry()

        do {
            var command = try await CLI.asyncParseAsRoot()
            if var asyncCommand = command as? any AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
            finishTelemetry(enabled: telemetryEnabled)
        } catch {
            captureTelemetry(error, enabled: telemetryEnabled)
            CLI.exit(withError: error)
        }
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
                LoggingSystem.bootstrap { _ in
                    SentryLogHandler(logLevel: .info)
                }
            } else {
                LoggingSystem.bootstrap { _ in
                    SwiftLogNoOpLogHandler()
                }
            }
            return enabled
        #else
            LoggingSystem.bootstrap { _ in
                SwiftLogNoOpLogHandler()
            }
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
