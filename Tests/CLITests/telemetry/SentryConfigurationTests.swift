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
