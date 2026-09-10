import ArgumentParser

struct CacheCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cache",
        abstract: "Manage cached Apple documentation.",
        subcommands: [CacheCleanCommand.self]
    )
}
