import ArgumentParser

struct AgentSkillsInstallCommand: ParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any (AgentSkillInstallationServiceProvider & CommandOutputWriterProvider)
    #else
        typealias Deps = Dependencies
    #endif

    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install bundled Agent Skills into a .agents directory.",
        discussion: """
            Installs into ~/.agents/skills by default. Use --project for a project-local installation.
            This selects the Git root, or the current directory outside Git. Use --dir for another root.
            Existing unmanaged files and symlinks are never overwritten, even with --force.

            Examples:
              apple-docs agent skills install apple-docs
              apple-docs agent skills install --all --dry-run
              apple-docs agent skills install --all --project
              apple-docs agent skills install apple-docs --force
            """
    )

    @OptionGroup var selection: AgentSkillsSelectionOptions

    @Flag(help: "Overwrite differing SKILL.md files only when managed by apple-docs.")
    var force = false

    mutating func validate() throws {
        _ = try selection.selectedSkills()
    }

    mutating func run() throws {
        try run(deps: Dependencies.shared)
    }

    func run(deps: Deps) throws {
        let output = try deps.agentSkillInstallationService().install(
            selection.selectedSkills(), root: selection.installationRoot(fileManager: deps.agentSkillFileManager()),
            dryRun: selection.dryRun, force: force
        )
        deps.commandOutputWriter.write(output)
    }
}
