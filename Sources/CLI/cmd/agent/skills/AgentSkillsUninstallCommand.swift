import ArgumentParser

struct AgentSkillsUninstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Remove skills managed by apple-docs from a .agents directory.",
        discussion: """
            Removes only unchanged managed files. Local edits, unrelated files, and other skills are preserved.
            Bulk removal requires --yes unless --dry-run is set. No interactive prompt is used.

            Examples:
              apple-docs agent skills uninstall apple-docs
              apple-docs agent skills uninstall --all --dry-run
              apple-docs agent skills uninstall --all --yes
              apple-docs agent skills uninstall --all --yes --dir .agents
            """
    )

    @OptionGroup var selection: AgentSkillsSelectionOptions

    @Flag(name: .shortAndLong, help: "Approve uninstalling all bundled skills.")
    var yes = false

    mutating func validate() throws {
        _ = try selection.selectedSkills()
        if selection.all, !yes, !selection.dryRun {
            throw ValidationError("Uninstalling all skills requires --yes. Use --dry-run to preview first.")
        }
    }

    mutating func run() throws {
        let output = try AgentSkillInstaller().uninstall(
            selection.selectedSkills(), root: selection.dir, dryRun: selection.dryRun
        )
        print(output)
    }
}
