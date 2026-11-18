import ArgumentParser

struct SupportGuidesCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "guides", abstract: "Discover help resources and browse supported guide contents.",
        subcommands: [SupportGuidesListCommand.self, SupportGuidesContentsCommand.self])
}

struct SupportGuidesListCommand: SupportExecutableCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions

    static let configuration = CommandConfiguration(
        commandName: "list", abstract: "List featured help resources, topic groups, and the glossary.")

    var request: SupportRequest { .helpCatalog }
}

struct SupportGuidesContentsCommand: SupportExecutableCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions
    @Option(help: "The guide identifier, such as app-store-connect.")
    var name: String

    static let configuration = CommandConfiguration(
        commandName: "contents", abstract: "Show the embedded table of contents for a supported guide.")

    var request: SupportRequest { .contents(name: name) }
}
