import Foundation
@preconcurrency import SentrySwift
import Testing

@testable import CLI

@Suite("Sentry configuration")
struct SentryConfigurationTests {
    @Test("enables telemetry by default")
    func enablesTelemetryByDefault() {
        // -- Arrange --
        let environment: [String: String] = [:]

        // -- Act --
        let enabled = SentryConfiguration.isEnabled(environment: environment)

        // -- Assert --
        #expect(enabled)
    }

    @Test(
        "disables telemetry for a true environmental flag",
        arguments: ["true", "TRUE", "True"]
    )
    func disablesTelemetry(value: String) {
        // -- Arrange --
        let environment = ["TELEMETRY_DISABLED": value]

        // -- Act --
        let enabled = SentryConfiguration.isEnabled(environment: environment)

        // -- Assert --
        #expect(!enabled)
    }

    @Test("marks CLI executable frames as in-app")
    func marksCLIExecutableFramesAsInApp() {
        // -- Arrange --
        let options = Options()

        // -- Act --
        SentryConfiguration.configure(options)

        // -- Assert --
        #expect(options.inAppIncludes.contains("apple-docs"))
    }

    @Test("treats documentation lookup failures as expected command errors")
    func treatsLookupFailureAsExpected() {
        // -- Arrange --
        let error = DefaultAppleDocumentationClient<URLSession>.Error.typeNotFound(
            name: "Model",
            technology: "SwiftData",
            suggestion: nil,
            technologyURL: "https://developer.apple.com/documentation/swiftdata"
        )

        // -- Act --
        let expected = SentryConfiguration.isExpected(error: error)

        // -- Assert --
        #expect(expected)
    }

    @Test("keeps telemetry enabled for other environmental flag values")
    func ignoresOtherFlagValues() {
        // -- Arrange --
        let environment = ["TELEMETRY_DISABLED": "false"]

        // -- Act --
        let enabled = SentryConfiguration.isEnabled(environment: environment)

        // -- Assert --
        #expect(enabled)
    }
}
