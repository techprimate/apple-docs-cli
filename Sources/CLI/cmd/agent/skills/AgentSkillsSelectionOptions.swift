import ArgumentParser

struct AgentSkillsSelectionOptions: ParsableArguments {
    @Argument(help: "One or more bundled skill names. Use 'agent skills list' to see available names.")
    var skills: [String] = []

    @Flag(help: "Select all bundled skills. Cannot be combined with skill names.")
    var all = false

    @Option(help: "Root of the .agents installation. Skills are stored under DIR/skills.")
    var dir = "~/.agents"

    @Flag(help: "Preview changes without writing or removing files.")
    var dryRun = false

    func selectedSkills() throws -> [BundledAgentSkill] {
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
}
