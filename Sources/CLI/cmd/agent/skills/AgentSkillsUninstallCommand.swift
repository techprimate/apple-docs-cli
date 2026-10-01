import ArgumentParser

struct AgentSkillsUninstallCommand: ParsableCommand, GlobalOptionsProviding {
    #if DEBUG
        typealias Deps = any AgentSkillInstallerProvider
    #else
        typealias Deps = Dependencies
    #endif

    @OptionGroup var global: GlobalOptions

    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Remove skills managed by apple-docs from a .agents directory.",
        discussion: """
            Removes only unchanged managed files. Local edits, unrelated files, and other skills are preserved.
            Use --project for the Git root (or current directory outside Git). Bulk removal requires --yes
            unless --dry-run is set. No interactive prompt is used.

            Examples:
              apple-docs agent skills uninstall apple-docs
              apple-docs agent skills uninstall --all --dry-run
              apple-docs agent skills uninstall --all --yes
              apple-docs agent skills uninstall --all --yes --project
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
        try run(deps: Dependencies.shared)
    }

    func run(deps: Deps) throws {
        let output = try deps.agentSkillInstaller().uninstall(
            selection.selectedSkills(), root: selection.installationRoot(fileManager: deps.agentSkillFileManager()),
            dryRun: selection.dryRun
        )
        print(output)
    }
}
