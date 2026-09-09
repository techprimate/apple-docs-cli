import ArgumentParser

struct TypesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "types",
        abstract: "Work with Apple documentation types.",
        subcommands: [TypesListCommand.self, TypesSearchCommand.self, TypesViewCommand.self]
    )
}
