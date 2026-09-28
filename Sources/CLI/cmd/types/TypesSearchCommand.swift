import ArgumentParser
import Foundation

struct TypesSearchCommand: AsyncParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any (
            TelemetryProvider & TerminalCapabilitiesProvider & DocumentationTypeSearchClientProvider
                & DocumentationTypeListRendererProvider
        )
    #else
        typealias Deps = Dependencies
    #endif

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
        try await run(deps: Dependencies.shared)
    }

    func run(deps: Deps) async throws {
        // Search text can be user-authored, so it is deliberately excluded from telemetry context.
        let context = TelemetryCommandContext.typesSearch(technology: technology, json: output.json)
        deps.telemetry.startCommand(context)
        let runner = TypesSearchCommandRunner(
            client: deps.documentationClient,
            renderer: deps.documentationTypeListRenderer(output: output, technology: technology)
        )
        let result = try await runner.run(
            query: query, technology: technology, mode: deps.terminalCapabilities.mode(for: output))
        deps.telemetry.record(.typeSearch(matches: result.matchCount), context: context)
        if result.unavailableCollectionCount > 0 {
            let warning =
                "Warning: search results are incomplete. "
                + "\(result.unavailableCollectionCount) collections were unavailable.\n"
            FileHandle.standardError.write(Data(warning.utf8))
        }
        print(result.output)
    }
}
