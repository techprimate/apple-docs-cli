import ArgumentParser

struct AgentSkillsListCommand: ParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any (TelemetryProvider & CommandOutputWriterProvider)
    #else
        typealias Deps = Dependencies
    #endif

    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List Agent Skills bundled with apple-docs."
    )

    mutating func run() throws {
        run(deps: Dependencies.shared)
    }

    func run(deps: Deps) {
        deps.telemetry.startCommand(.agentSkillsList)
        for skill in BundledAgentSkills.all {
            deps.commandOutputWriter.write("\(skill.name)\t\(skill.shortDescription)")
        }
    }
}
