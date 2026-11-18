import ArgumentParser

struct AgentSkillsUpdateCommand: ParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any (AgentSkillInstallationServiceProvider & CommandOutputWriterProvider)
    #else
        typealias Deps = Dependencies
    #endif

    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update installed skills managed by apple-docs.",
        discussion: """
            With no names, updates all managed bundled skills already installed. Does not install missing
            or unmanaged skills. Local edits are preserved and must be resolved before updating.
            Use --project for the Git root (current directory outside Git), or --dir for another root.

            Examples:
              apple-docs agent skills update
              apple-docs agent skills update --dry-run
              apple-docs agent skills update apple-docs --project
            """
    )

    @OptionGroup var selection: AgentSkillsSelectionOptions

    mutating func validate() throws {
        _ = try selection.selectedSkills(defaultToAll: true)
    }

    mutating func run() throws {
        try run(deps: AppleDocs.dependencies)
    }

    func run(deps: Deps) throws {
        do {
            let outcomes = try deps.agentSkillInstallationService().update(
                selection.selectedSkills(defaultToAll: true),
                root: selection.root.installationRoot(fileManager: deps.agentSkillFileManager()),
                dryRun: selection.dryRun
            )
            deps.commandOutputWriter.write(AgentSkillInstallationRenderer().render(outcomes))
        } catch let failure as AgentSkillBatchFailure {
            deps.commandOutputWriter.write(AgentSkillInstallationRenderer().render(failure.completed))
            if let error = failure.underlying as? AgentSkillInstallationError {
                throw ValidationError(error.localizedDescription)
            }
            throw failure.underlying
        } catch let error as AgentSkillInstallationError {
            throw ValidationError(error.localizedDescription)
        }
    }
}
