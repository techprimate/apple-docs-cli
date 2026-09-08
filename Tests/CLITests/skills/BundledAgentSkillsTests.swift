import Testing

@testable import CLI

@Suite("Bundled agent skills")
struct BundledAgentSkillsTests {
    @Test("lists the bundled Apple documentation skill")
    func listsBundledSkill() {
        #expect(BundledAgentSkills.all.map(\.name) == ["apple-docs"])
    }

    @Test("loads a bundled skill by name")
    func loadsBundledSkill() throws {
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))
        let content = skill.content

        #expect(content.hasPrefix("---\nname: apple-docs\n"))
    }

    @Test("returns no skill for an unknown name")
    func rejectsUnknownSkill() {
        #expect(BundledAgentSkills.skill(named: "unknown") == nil)
    }
}
