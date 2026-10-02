import Logging

@testable import CLI

final class RecordingCommandOutputWriter: CommandOutputWriting {
    private(set) var lines: [String] = []
    private(set) var warnings: [String] = []

    func write(_ line: String) { lines.append(line) }
    func writeWarning(_ warning: String) { warnings.append(warning) }
}

final class RecordingCommandTelemetry: Telemetry, @unchecked Sendable {
    private(set) var commands: [String] = []
    private(set) var metrics: [TelemetryMetric] = []

    func start() {}
    func startCommand(_ context: TelemetryCommandContext) { commands.append(context.command) }
    func record(_ metric: TelemetryMetric, context: TelemetryCommandContext) { metrics.append(metric) }
    func finishCommand(error: (any Error)?) {}
    func makeLogHandler() -> (any LogHandler)? { nil }
}
