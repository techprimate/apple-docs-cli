import ArgumentParser
import Foundation

struct TypesSearchCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search types in an Apple documentation technology."
    )

    @Argument(help: "The type name or path to search for.")
    var query: String

    @Option(help: "The framework or technology whose types to search.")
    var technology: String

    mutating func run() async throws {
        try await run(telemetry: Dependencies.telemetry)
    }

    func run(telemetry: Telemetry) async throws {
        // Search text can be user-authored, so it is deliberately excluded from telemetry context.
        let context = TelemetryCommandContext.typesSearch(technology: technology, json: output.json)
        telemetry.startCommand(context)
        let result = try await TypesSearchCommandRunner(
            client: Dependencies.documentationClient,
            renderer: Dependencies.documentationTypeListRenderer(output: output, technology: technology)
        ).run(query: query, technology: technology)
        telemetry.record(.typeSearch(matches: result.matchCount), context: context)
        if result.unavailableCollectionCount > 0 {
            let warning =
                "Warning: search results are incomplete. "
                + "\(result.unavailableCollectionCount) collections were unavailable.\n"
            FileHandle.standardError.write(Data(warning.utf8))
        }
        print(result.output)
    }
}
