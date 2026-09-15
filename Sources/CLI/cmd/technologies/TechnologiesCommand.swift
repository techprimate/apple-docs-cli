import ArgumentParser

struct TechnologiesCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "technologies",
        abstract: "Work with Apple documentation technologies.",
        subcommands: [TechnologiesListCommand.self]
    )
}
