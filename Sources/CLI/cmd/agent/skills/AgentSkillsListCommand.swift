import ArgumentParser

struct AgentSkillsListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List Agent Skills bundled with apple-docs."
    )

    mutating func run() throws {
        for skill in BundledAgentSkills.all {
            print("\(skill.name)\t\(skill.shortDescription)")
        }
    }
}
