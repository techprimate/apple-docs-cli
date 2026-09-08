import ArgumentParser

struct AgentSkillsGetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print a bundled Agent Skill."
    )

    @Argument(help: "The bundled skill name.")
    var name: String

    mutating func run() throws {
        guard let skill = BundledAgentSkills.skill(named: name) else {
            throw ValidationError("Unknown bundled Agent Skill '\(name)'.")
        }
        print(skill.content)
    }
}
