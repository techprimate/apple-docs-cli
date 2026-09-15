import ArgumentParser

struct TechnologiesListCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List Apple documentation technologies."
    )

    @Flag(
        name: [.long, .customLong("agent")],
        help: "Output a JSON array of technologies. --agent currently aliases --json."
    )
    var json = false

    mutating func run() async throws {
        try await run(telemetry: Dependencies.telemetry)
    }

    func run(telemetry: Telemetry) async throws {
        let context = TelemetryCommandContext.technologiesList(json: json)
        telemetry.startCommand(context)
        let result = try await TechnologiesListCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.technologyListRenderer(json: json)
        ).run()
        telemetry.record(.technologyCatalog(count: result.technologyCount), context: context)
        print(result.output)
    }
}
