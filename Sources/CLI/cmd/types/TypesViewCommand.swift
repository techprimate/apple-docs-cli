import ArgumentParser

struct TypesViewCommand: AsyncParsableCommand, GlobalOptionsProviding {
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
        try await run(telemetry: Dependencies.telemetry)
    }

    func run(telemetry: Telemetry) async throws {
        let context = TelemetryCommandContext.typesView(name: name, technology: technology, json: output.json)
        telemetry.startCommand(context)
        let result = try await TypesViewCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.documentationRenderer(output: output)
        ).run(name: name, technology: technology)
        telemetry.record(.typeView(responseBytes: result.responseByteCount), context: context)
        print(result.output)
    }
}
