import ArgumentParser

struct TypesListCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List types in an Apple documentation technology."
    )

    @Option(help: "The framework or technology whose types to list.")
    var technology: String

    mutating func run() async throws {
        try await run(telemetry: Dependencies.telemetry)
    }

    func run(telemetry: Telemetry) async throws {
        let context = TelemetryCommandContext.typesList(technology: technology, json: output.json)
        telemetry.startCommand(context)
        let result = try await TypesListCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.documentationTypeListRenderer(output: output, technology: technology)
        ).run(technology: technology)
        telemetry.record(.typeCatalog(count: result.typeCount), context: context)
        print(result.output)
    }
}
