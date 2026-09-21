import ArgumentParser

struct TypesSearchCommand: DocumentationCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(
        commandName: "search", abstract: "Search types in an Apple documentation technology.")

    @Argument(help: "The type name or path to search for.") var query: String
    @Option(help: "The framework or technology whose types to search.") var technology: String

    var entry: BrowserEntry { .search(query: query, technology: technology) }
    // User-authored search text is deliberately excluded from telemetry.
    var telemetryContext: TelemetryCommandContext { .typesSearch(technology: technology, json: output.json) }
}
