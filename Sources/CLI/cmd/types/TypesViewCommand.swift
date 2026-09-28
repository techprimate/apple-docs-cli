import ArgumentParser

struct TypesViewCommand: AsyncParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any (
            TelemetryProvider & TerminalCapabilitiesProvider & AppleDocumentationClientProvider
                & TypeDocumentationRendererProvider
        )
    #else
        typealias Deps = Dependencies
    #endif

    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "Show documentation for a type."
    )

    @Argument(help: "The type name.")
    var name: String

    @Option(help: "The framework or technology containing the type.")
    var technology: String

    mutating func run() async throws {
        try await run(deps: Dependencies.shared)
    }

    func run(deps: Deps) async throws {
        let context = TelemetryCommandContext.typesView(name: name, technology: technology, json: output.json)
        deps.telemetry.startCommand(context)
        let runner = TypesViewCommandRunner(
            client: deps.documentationClient,
            renderer: deps.documentationRenderer(output: output)
        )
        let result = try await runner.run(name: name, technology: technology, mode: deps.terminalCapabilities.mode(for: output))
        deps.telemetry.record(.typeView(responseBytes: result.responseByteCount), context: context)
        print(result.output)
    }
}
