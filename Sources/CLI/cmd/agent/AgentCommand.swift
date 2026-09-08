import ArgumentParser

struct AgentCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Agent mode utilities.",
        subcommands: [AgentSkillsCommand.self]
    )
}
