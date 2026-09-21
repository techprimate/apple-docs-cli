import ArgumentParser

protocol DocumentationCommand: AsyncParsableCommand, GlobalOptionsProviding, OutputOptionsProviding {
    var entry: BrowserEntry { get }
    var telemetryContext: TelemetryCommandContext { get }
}

extension DocumentationCommand {
    @MainActor
    mutating func run() async throws {
        let capabilities = TerminalCapabilities.current
        let mode = output.mode(stdinIsTTY: capabilities.stdinIsTTY, stdoutIsTTY: capabilities.stdoutIsTTY)
        try await run(
            mode: mode, logs: mode == .interactive ? SessionLogBuffer() : nil, telemetry: Dependencies.telemetry)
    }

    @MainActor
    func run(mode: OutputMode, logs: SessionLogBuffer?, telemetry: Telemetry) async throws {
        telemetry.startCommand(telemetryContext)
        try await Dependencies.documentationDispatcher(logs: logs, telemetry: telemetry)
            .run(entry: entry, mode: mode, context: telemetryContext)
    }
}
