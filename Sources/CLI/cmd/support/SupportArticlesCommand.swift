import ArgumentParser

struct SupportArticlesCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "articles", abstract: "Discover categorized support resources.",
        subcommands: [SupportArticlesListCommand.self])
}

struct SupportArticlesListCommand: SupportExecutableCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions
    @Option(help: "Filter by a source category identifier, such as membership.")
    var category: String?

    static let configuration = CommandConfiguration(
        commandName: "list", abstract: "List support article categories and their resource links.")

    var request: SupportRequest { .articles(category: category) }
}
