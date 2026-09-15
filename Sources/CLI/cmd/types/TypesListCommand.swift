import ArgumentParser

struct TypesListCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List types in an Apple documentation technology."
    )

    @Option(help: "The framework or technology whose types to list.")
    var technology: String

    @Flag(
        name: [.long, .customLong("agent")],
        help: "Output a JSON array of types. --agent currently aliases --json."
    )
    var json = false

    mutating func run() async throws {
        try await run(telemetry: Dependencies.telemetry)
    }

    func run(telemetry: Telemetry) async throws {
        let context = TelemetryCommandContext.typesList(technology: technology, json: json)
        telemetry.startCommand(context)
        let result = try await TypesListCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.documentationTypeListRenderer(json: json)
        ).run(technology: technology)
        telemetry.record(.typeCatalog(count: result.typeCount), context: context)
        print(result.output)
    }
}
