import ArgumentParser

struct AgentSkillsListCommand: ParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any (TelemetryProvider & CommandOutputWriterProvider & AgentSkillInstallationServiceProvider)
    #else
        typealias Deps = Dependencies
    #endif

    @OptionGroup var global: GlobalOptions
    @OptionGroup var root: AgentSkillsRootOptions

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List bundled Agent Skills with installation status and paths."
    )

    mutating func run() throws {
        try run(deps: AppleDocs.dependencies)
    }

    func run(deps: Deps) throws {
        deps.telemetry.startCommand(.agentSkillsList)
        do {
            let installations = try deps.agentSkillInstallationService().list(
                BundledAgentSkills.all, root: root.installationRoot(fileManager: deps.agentSkillFileManager()))
            for line in AgentSkillInstallationRenderer().renderList(installations) {
                deps.commandOutputWriter.write(line)
            }
        } catch let error as AgentSkillInstallationError {
            throw ValidationError(error.localizedDescription)
        }
    }
}
