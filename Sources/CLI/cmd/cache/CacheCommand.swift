import ArgumentParser

struct CacheCommand: ParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "cache",
        abstract: "Manage cached Apple documentation.",
        subcommands: [CacheCleanCommand.self]
    )
}
