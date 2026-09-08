import ArgumentParser

struct TechnologiesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "technologies",
        abstract: "Work with Apple documentation technologies.",
        subcommands: [TechnologiesListCommand.self]
    )
}
