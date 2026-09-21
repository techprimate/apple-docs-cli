import ArgumentParser

struct TechnologiesListCommand: DocumentationCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(
        commandName: "list", abstract: "List Apple documentation technologies.")

    var entry: BrowserEntry { .technologies }
    var telemetryContext: TelemetryCommandContext { .technologiesList(json: output.json) }
}
