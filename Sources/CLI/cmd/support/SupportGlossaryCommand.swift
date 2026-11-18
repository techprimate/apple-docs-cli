import ArgumentParser

struct SupportGlossaryCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "glossary", abstract: "Look up terms used in Apple development and distribution.",
        subcommands: [SupportGlossaryListCommand.self, SupportGlossaryViewCommand.self])
}

struct SupportGlossaryListCommand: SupportExecutableCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions
    @Option(help: "Filter term names by a case-insensitive substring, not definition text.")
    var query: String?

    static let configuration = CommandConfiguration(
        commandName: "list", abstract: "List glossary terms and structured definitions.")

    var request: SupportRequest { .glossary(query: query) }
}

struct SupportGlossaryViewCommand: SupportExecutableCommand {
    @OptionGroup var global: GlobalOptions
    @OptionGroup var output: OutputOptions
    @Option(help: "The exact displayed term, matched case-insensitively.")
    var term: String

    static let configuration = CommandConfiguration(
        commandName: "view", abstract: "Show one glossary definition.")

    var request: SupportRequest { .glossaryEntry(term: term) }
}
