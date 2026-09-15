import ArgumentParser

struct AgentCommand: ParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Agent mode utilities.",
        subcommands: [AgentSkillsCommand.self]
    )
}
