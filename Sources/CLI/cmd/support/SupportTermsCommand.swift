import ArgumentParser

struct SupportTermsCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "terms", abstract: "Browse the agreements and guidelines catalog.",
        subcommands: [SupportTermsListCommand.self, SupportTermsViewCommand.self])
}

struct SupportTermsListCommand: SupportExecutableCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions
    @Option(help: "Filter by a source category identifier, such as guidelines.")
    var category: String?

    static let configuration = CommandConfiguration(
        commandName: "list", abstract: "List agreements, guidelines, and their available resources.")

    var request: SupportRequest { .terms(category: category) }
}

struct SupportTermsViewCommand: SupportExecutableCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions
    @Option(help: "The terms entry identifier returned by the catalog.")
    var name: String

    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "Show a catalog entry and its translations, not the linked legal document.")

    var request: SupportRequest { .termsEntry(name: name) }
}
