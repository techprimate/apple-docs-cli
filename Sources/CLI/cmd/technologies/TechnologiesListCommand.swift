import ArgumentParser

struct TechnologiesListCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List Apple documentation technologies."
    )

    mutating func run() async throws {
        try await run(telemetry: Dependencies.telemetry)
    }

    func run(telemetry: Telemetry) async throws {
        let context = TelemetryCommandContext.technologiesList(json: output.json)
        telemetry.startCommand(context)
        let result = try await TechnologiesListCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.technologyListRenderer(output: output)
        ).run()
        telemetry.record(.technologyCatalog(count: result.technologyCount), context: context)
        print(result.output)
    }
}
