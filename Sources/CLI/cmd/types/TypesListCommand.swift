import ArgumentParser

struct TypesListCommand: DocumentationCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(
        commandName: "list", abstract: "List types in an Apple documentation technology.")

    @Option(help: "The framework or technology whose types to list.") var technology: String

    var entry: BrowserEntry { .types(technology: technology) }
    var telemetryContext: TelemetryCommandContext { .typesList(technology: technology, json: output.json) }
}
