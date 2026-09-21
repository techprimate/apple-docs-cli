import ArgumentParser

struct TypesViewCommand: DocumentationCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(commandName: "view", abstract: "Show documentation for a type.")

    @Argument(help: "The type name.") var name: String
    @Option(help: "The framework or technology containing the type.") var technology: String

    var entry: BrowserEntry { .type(name: name, technology: technology) }
    var telemetryContext: TelemetryCommandContext {
        .typesView(name: name, technology: technology, json: output.json)
    }
}
