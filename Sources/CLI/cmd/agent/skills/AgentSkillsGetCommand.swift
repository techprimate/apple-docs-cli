import ArgumentParser

struct AgentSkillsGetCommand: ParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print a bundled Agent Skill."
    )

    @Argument(help: "The bundled skill name.")
    var name: String

    mutating func run() throws {
        try run(telemetry: Dependencies.telemetry)
    }

    func run(telemetry: Telemetry) throws {
        telemetry.startCommand(.agentSkillsGet)
        guard let skill = BundledAgentSkills.skill(named: name) else {
            throw ValidationError("Unknown bundled Agent Skill '\(name)'.")
        }
        print(skill.content)
    }
}
