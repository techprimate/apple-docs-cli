import ArgumentParser

struct AgentSkillsInstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install bundled Agent Skills into a .agents directory.",
        discussion: """
            Installs into ~/.agents/skills by default. Use --dir .agents for a project-local installation.
            Existing unmanaged files and symlinks are never overwritten, even with --force.

            Examples:
              apple-docs agent skills install apple-docs
              apple-docs agent skills install --all --dry-run
              apple-docs agent skills install --all --dir .agents
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
        let output = try AgentSkillInstaller().install(
            selection.selectedSkills(), root: selection.dir, dryRun: selection.dryRun, force: force
        )
        print(output)
    }
}
