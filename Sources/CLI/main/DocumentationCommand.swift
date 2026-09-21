import ArgumentParser

protocol DocumentationCommand: AsyncParsableCommand, GlobalOptionsProviding, OutputOptionsProviding {
    var entry: BrowserEntry { get }
    var telemetryContext: TelemetryCommandContext { get }
}

extension DocumentationCommand {
    @MainActor
    mutating func run() async throws {
        let deps = Dependencies.shared
        let mode = deps.terminalCapabilities.mode(for: output)
        try await run(
            mode: mode, logs: mode == .interactive ? SessionLogBuffer() : nil, telemetry: deps.telemetry)
    }

    @MainActor
    func run(mode: OutputMode, logs: SessionLogBuffer?, telemetry: Telemetry) async throws {
        try await run(
            mode: mode, telemetry: telemetry,
            dispatcher: Dependencies.shared.documentationDispatcher(logs: logs, telemetry: telemetry))
    }

    func run(mode: OutputMode, telemetry: Telemetry, dispatcher: DocumentationCommandDispatcher) async throws {
        telemetry.startCommand(telemetryContext)
        try await dispatcher.run(entry: entry, mode: mode, context: telemetryContext)
    }
}
