import ArgumentParser

struct TypesViewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "Show documentation for a type."
    )

    @Argument(help: "The type name.")
    var name: String

    @Option(help: "The framework or technology containing the type.")
    var technology: String

    @Flag(help: "Output the raw Apple DocC JSON document.")
    var json = false

    mutating func run() async throws {
        let output = try await TypesViewCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.documentationRenderer(json: json)
        ).run(name: name, technology: technology)
        print(output)
    }
}
