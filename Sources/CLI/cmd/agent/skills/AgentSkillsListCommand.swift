import ArgumentParser

struct AgentSkillsListCommand: ParsableCommand, GlobalOptionsProviding {
    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List Agent Skills bundled with apple-docs."
    )

    mutating func run() throws {
        run(telemetry: Dependencies.telemetry)
    }

    func run(telemetry: Telemetry) {
        telemetry.startCommand(.agentSkillsList)
        for skill in BundledAgentSkills.all {
            print("\(skill.name)\t\(skill.shortDescription)")
        }
    }
}
