import ArgumentParser

struct TypesListCommand: AsyncParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any (
            TelemetryProvider & TerminalCapabilitiesProvider & DocumentationTypeCatalogClientProvider
                & DocumentationTypeListRendererProvider
        )
    #else
        typealias Deps = Dependencies
    #endif

    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List types in an Apple documentation technology."
    )

    @Option(help: "The framework or technology whose types to list.")
    var technology: String

    mutating func run() async throws {
        try await run(deps: Dependencies.shared)
    }

    func run(deps: Deps) async throws {
        let context = TelemetryCommandContext.typesList(technology: technology, json: output.json)
        deps.telemetry.startCommand(context)
        let runner = TypesListCommandRunner(
            client: deps.documentationClient,
            renderer: deps.documentationTypeListRenderer(output: output, technology: technology)
        )
        let result = try await runner.run(technology: technology, mode: deps.terminalCapabilities.mode(for: output))
        deps.telemetry.record(.typeCatalog(count: result.typeCount), context: context)
        print(result.output)
    }
}
