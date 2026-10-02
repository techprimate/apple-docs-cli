import ArgumentParser
import Foundation

struct AgentSkillsSelectionOptions: ParsableArguments {
    @Argument(help: "One or more bundled skill names. Use 'agent skills list' to see available names.")
    var skills: [String] = []

    @Flag(help: "Select all bundled skills. Cannot be combined with skill names.")
    var all = false

    @Option(help: "Root of the .agents installation. Skills are stored under DIR/skills.")
    var dir: String?

    @Flag(
        help: "Use the Git root's .agents directory (current directory outside Git). Conflicts with --dir."
    )
    var project = false

    @Flag(help: "Preview changes without writing or removing files.")
    var dryRun = false

    func selectedSkills() throws -> [BundledAgentSkill] {
        if project, dir != nil {
            throw ValidationError("Use either --project or --dir, not both.")
        }
        guard all != !skills.isEmpty else {
            throw ValidationError("Specify one or more skill names, or --all, but not both.")
        }
        if all { return BundledAgentSkills.all }
        var seen = Set<String>()
        return try skills.compactMap { name in
            guard let skill = BundledAgentSkills.skill(named: name) else {
                throw ValidationError("Unknown bundled Agent Skill '\(name)'. Run 'apple-docs agent skills list'.")
            }
            return seen.insert(name).inserted ? skill : nil
        }
    }

    func installationRoot(fileManager: AgentSkillFileSystem) -> String {
        if project {
            let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath).standardizedFileURL
            var directory = currentDirectory
            while !fileManager.fileExists(atPath: directory.appendingPathComponent(".git").path) {
                if directory.path == "/" { break }
                directory = directory.deletingLastPathComponent()
            }
            let root =
                fileManager.fileExists(atPath: directory.appendingPathComponent(".git").path)
                ? directory : currentDirectory
            return root.appendingPathComponent(".agents").path
        }
        return dir ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".agents").path
    }
}
