import ArgumentParser

struct TypesCommand: AsyncParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "types",
        abstract: "Work with Apple documentation types.",
        subcommands: [TypesListCommand.self, TypesSearchCommand.self, TypesViewCommand.self]
    )
}
