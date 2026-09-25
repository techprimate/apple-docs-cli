import Testing

@testable import CLI

@Suite("Bundled agent skills")
struct BundledAgentSkillsTests {
    @Test("makes the research workflows discoverable by name")
    func listsBundledSkills() {
        // -- Arrange --
        let names = ["apple-docs", "apple-docs-discover-api", "apple-docs-check-availability"]

        // -- Act --
        let skills = names.compactMap { BundledAgentSkills.skill(named: $0) }

        // -- Assert --
        #expect(skills.map(\.name) == names)
        #expect(Set(BundledAgentSkills.all.map(\.name)).count == BundledAgentSkills.all.count)
    }

    @Test("loads a bundled skill by name")
    func loadsBundledSkill() throws {
        // -- Arrange --
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))

        // -- Act --
        let content = skill.content

        // -- Assert --
        #expect(content.hasPrefix("---\nname: apple-docs\n"))
    }

    @Test("research examples select the agent audience and structured evidence uses both flags")
    func researchExamplesUseAgentMode() {
        // -- Arrange --
        let skills = BundledAgentSkills.all

        // -- Act --
        let examples = skills.flatMap { $0.content.split(separator: "\n") }.filter {
            $0.hasPrefix("apple-docs types ") || $0.hasPrefix("apple-docs technologies ")
        }

        // -- Assert --
        #expect(!examples.isEmpty)
        #expect(examples.allSatisfy { $0.contains("--agent") })
        #expect(examples.contains { $0.contains("--agent --json") })
        #expect(skills.allSatisfy { !$0.content.contains("aliases `--json`") })
    }

    @Test("returns no skill for an unknown name")
    func rejectsUnknownSkill() {
        // -- Arrange --
        let name = "unknown"

        // -- Act --
        let skill = BundledAgentSkills.skill(named: name)

        // -- Assert --
        #expect(skill == nil)
    }
}
