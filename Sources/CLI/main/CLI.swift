import ArgumentParser

@main
struct CLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apple-docs",
        abstract: "Access Apple developer documentation from the command line.",
        discussion: """
            Run 'apple-docs agent skills list' to see bundled Agent Skills with task-specific guidance.
            """,
        subcommands: [
            TypeCommand.self,
            AgentCommand.self,
        ]
    )
}
