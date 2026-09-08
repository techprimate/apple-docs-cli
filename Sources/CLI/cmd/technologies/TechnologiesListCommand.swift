import ArgumentParser

struct TechnologiesListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List Apple documentation technologies."
    )

    @Flag(help: "Output a JSON array of technologies.")
    var json = false

    mutating func run() async throws {
        let output = try await TechnologiesListCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.technologyListRenderer(json: json)
        ).run()
        print(output)
    }
}
