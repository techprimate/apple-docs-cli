import ArgumentParser

struct TechnologiesListCommand: AsyncParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any (
            TelemetryProvider & TerminalCapabilitiesProvider & TechnologyCatalogClientProvider
                & TechnologyListRendererProvider & CommandOutputWriterProvider
        )
    #else
        typealias Deps = Dependencies
    #endif

    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List Apple documentation technologies."
    )

    mutating func run() async throws {
        try await run(deps: Dependencies.shared)
    }

    func run(deps: Deps) async throws {
        let context = TelemetryCommandContext.technologiesList(json: output.json)
        deps.telemetry.startCommand(context)
        let runner = TechnologiesListCommandRunner(
            client: deps.documentationClient,
            renderer: deps.technologyListRenderer(output: output)
        )
        let result = try await runner.run(mode: deps.terminalCapabilities.mode(for: output))
        deps.telemetry.record(.technologyCatalog(count: result.technologyCount), context: context)
        deps.commandOutputWriter.write(result.output)
    }
}
