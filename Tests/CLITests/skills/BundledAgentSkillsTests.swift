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
