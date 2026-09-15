import ArgumentParser

struct TypesViewCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "Show documentation for a type."
    )

    @Argument(help: "The type name.")
    var name: String

    @Option(help: "The framework or technology containing the type.")
    var technology: String

    @Flag(
        name: [.long, .customLong("agent")],
        help: "Output the raw Apple DocC JSON document. --agent currently aliases --json."
    )
    var json = false

    mutating func run() async throws {
        try await run(telemetry: Dependencies.telemetry)
    }

    func run(telemetry: Telemetry) async throws {
        let context = TelemetryCommandContext.typesView(name: name, technology: technology, json: json)
        telemetry.startCommand(context)
        let result = try await TypesViewCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.documentationRenderer(json: json)
        ).run(name: name, technology: technology)
        telemetry.record(.typeView(responseBytes: result.responseByteCount), context: context)
        print(result.output)
    }
}
