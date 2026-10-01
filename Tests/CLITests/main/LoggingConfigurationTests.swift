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
    @Test(
        "interactive logging is buffered at info level without verbose and debug level with verbose",
        arguments: [false, true])
    func buffersInteractiveLogs(verbose: Bool) {
        // -- Arrange --
        let buffer = LogBuffer()
        let telemetry = ClientLogRecorder()
        let logger = Logger(label: "test") { label in
            LoggingConfiguration.handler(
                console: buffer.handler(label: label), telemetry: telemetry.handler(), verbose: verbose,
                interactive: true)
        }

        // -- Act --
        for level in [Logger.Level.debug, .info, .warning] {
            logger.log(level: level, "Test event", metadata: ["request": "test"])
        }

        // -- Assert --
        #expect(buffer.entries.map(\.event.level) == (verbose ? [.debug, .info, .warning] : [.info, .warning]))
        #expect(
            buffer.entries.allSatisfy { $0.label == "test" && $0.event.metadata?["request"]?.description == "test" })
        #expect(telemetry.events.map(\.level) == [.info, .warning])
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
