import ArgumentParser

struct AgentSkillsCommand: ParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "skills",
        abstract: "Access portable Agent Skills bundled with apple-docs.",
        subcommands: [
            AgentSkillsListCommand.self,
            AgentSkillsGetCommand.self,
            AgentSkillsInstallCommand.self,
            AgentSkillsUninstallCommand.self,
        ]
    )
}
