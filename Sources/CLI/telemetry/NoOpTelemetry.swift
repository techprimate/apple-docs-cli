import Logging

struct NoOpTelemetry: Sendable {
    init(logger: @escaping @Sendable () -> Logger, environment: [String: String]) {}

    func start() {}
    func startCommand(_ context: TelemetryCommandContext) {}
    func record(_ metric: TelemetryMetric, context: TelemetryCommandContext) {}
    func finishCommand(error: (any Error)?) {}
    func makeLogHandler() -> (any LogHandler)? { nil }
}
