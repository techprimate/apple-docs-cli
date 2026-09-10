import ArgumentParser

struct CLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apple-docs",
        abstract: "Access Apple developer documentation from the command line.",
        discussion: """
            Run 'apple-docs agent skills list' to see bundled Agent Skills with task-specific guidance.
            """,
        version: BuildMetadata.formatted,
        subcommands: [
            TypesCommand.self,
            TechnologiesCommand.self,
            CacheCommand.self,
            AgentCommand.self,
        ]
    )
}
