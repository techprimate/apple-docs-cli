import Logging
import Testing

@testable import CLI

@Suite("Global logging configuration")
struct LoggingConfigurationTests {
    @available(macOS 15, *)
    @Test("verbose controls console logs independently of telemetry", arguments: [false, true])
    func routesTelemetryIndependently(verbose: Bool) {
        // -- Arrange --
        let console = ClientLogRecorder()
        let telemetry = ClientLogRecorder()
        let logger = Logger(label: "test") { _ in
            LoggingConfiguration.handler(console: console.handler(), telemetry: telemetry.handler(), verbose: verbose)
        }

        // -- Act --
        for level in [Logger.Level.trace, .debug, .info, .notice, .warning, .error, .critical] {
            logger.log(level: level, "Test event", metadata: ["request": "test"])
        }

        // -- Assert --
        let expectedConsole: [Logger.Level] = verbose ? [.debug, .info, .notice, .warning, .error, .critical] : []
        #expect(console.events.map(\.level) == expectedConsole)
        #expect(telemetry.events.map(\.level) == [.info, .notice, .warning, .error, .critical])
        #expect(telemetry.events.allSatisfy { $0.metadata?["request"]?.description == "test" })
    }

    @available(macOS 15, *)
    @Test("verbose works with telemetry disabled and stays quiet by default", arguments: [false, true])
    func routesWithoutTelemetry(verbose: Bool) {
        // -- Arrange --
        let console = ClientLogRecorder()
        let logger = Logger(label: "test") { _ in
            LoggingConfiguration.handler(console: console.handler(), telemetry: nil, verbose: verbose)
        }

        // -- Act --
        for level in [Logger.Level.trace, .debug, .info, .notice, .warning, .error, .critical] {
            logger.log(level: level, "Test event", metadata: ["request": "test"])
        }

        // -- Assert --
        let expected: [Logger.Level] = verbose ? [.debug, .info, .notice, .warning, .error, .critical] : []
        #expect(console.events.map(\.level) == expected)
        #expect(console.events.allSatisfy { $0.metadata?["request"]?.description == "test" })
    }
}
