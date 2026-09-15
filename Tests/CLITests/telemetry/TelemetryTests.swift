import ArgumentParser
import Logging
import Testing

@testable import CLI

@Suite("Telemetry service")
struct TelemetryTests {
    @available(macOS 15, *)
    @Test("disabled telemetry neither creates its logger nor provides a log handler")
    func disabledTelemetryIsNoOp() {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let logger = Logger(label: "test") { _ in recorder.handler() }
        let telemetry = DefaultTelemetry(
            logger: {
                logger.info("Logger created")
                return logger
            },
            environment: ["TELEMETRY_DISABLED": "TRUE"]
        )
        let context = TelemetryCommandContext.typesView(name: "String", technology: "Swift", json: true)

        // -- Act --
        telemetry.start()
        telemetry.startCommand(context)
        telemetry.record(.typeView(responseBytes: 123), context: context)
        telemetry.finishCommand(error: nil)
        telemetry.finishCommand(error: ValidationError("Invalid request"))

        // -- Assert --
        #expect(telemetry.makeLogHandler() == nil)
        #expect(recorder.events.isEmpty)
    }

    @available(macOS 15, *)
    @Test("no-op telemetry never creates its logger, even without an opt-out flag")
    func unsupportedTelemetryIsNoOp() {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let logger = Logger(label: "test") { _ in recorder.handler() }
        let telemetry = NoOpTelemetry(
            logger: {
                logger.info("Logger created")
                return logger
            },
            environment: [:]
        )

        // -- Act --
        telemetry.start()
        telemetry.startCommand(.agentSkillsList)
        telemetry.record(.technologyCatalog(count: 10), context: .technologiesList(json: false))
        telemetry.finishCommand(error: nil)

        // -- Assert --
        #expect(telemetry.makeLogHandler() == nil)
        #expect(recorder.events.isEmpty)
    }

    @Test("skill commands start the injected telemetry before a lookup failure")
    func injectsCommandTelemetry() throws {
        // -- Arrange --
        let command = try AgentSkillsGetCommand.parse(["unknown-skill"])
        let telemetry = CommandTelemetryRecorder()

        // -- Act --
        #expect(throws: ValidationError.self) {
            try command.run(telemetry: telemetry)
        }

        // -- Assert --
        #expect(telemetry.contexts.map(\.command) == ["agent.skills.get"])
        #expect(telemetry.contexts.first?.typeName == nil)
        #expect(telemetry.contexts.first?.technology == nil)
    }
}

private final class CommandTelemetryRecorder: Telemetry, @unchecked Sendable {
    // Accessed only by the synchronous command under test.
    private(set) var contexts: [TelemetryCommandContext] = []

    func start() {}
    func startCommand(_ context: TelemetryCommandContext) {
        contexts.append(context)
    }
    func record(_ metric: TelemetryMetric, context: TelemetryCommandContext) {}
    func finishCommand(error: (any Error)?) {}
    func makeLogHandler() -> (any LogHandler)? { nil }
}
