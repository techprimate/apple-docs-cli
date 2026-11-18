import Foundation
import Testing

@testable import CLI

@Suite("Skill installation reporting")
struct AgentSkillInstallationRendererTests {
    @Test("distinguishes updates from new installations and summarizes outcomes")
    func reportsInstallAndUpdate() {
        // -- Arrange --
        let file = URL(fileURLWithPath: "/tmp/skills/example/SKILL.md")
        let outcomes = [
            AgentSkillInstallationOutcome(name: "new", file: file, status: .installed),
            AgentSkillInstallationOutcome(name: "old", file: file, status: .updated),
            AgentSkillInstallationOutcome(name: "current", file: file, status: .unchanged),
        ]

        // -- Act --
        let output = AgentSkillInstallationRenderer().render(outcomes)

        // -- Assert --
        #expect(output.contains("Installed: new at"))
        #expect(output.contains("Updated: old at"))
        #expect(output.contains("Unchanged: current"))
        #expect(output.hasSuffix("Summary: 1 installed, 1 updated, 1 unchanged"))
    }

    @Test("reports preview counts without claiming changes were made")
    func reportsPreview() {
        // -- Arrange --
        let file = URL(fileURLWithPath: "/tmp/skills/example/SKILL.md")
        let outcomes = [
            AgentSkillInstallationOutcome(name: "new", file: file, status: .wouldInstall),
            AgentSkillInstallationOutcome(name: "old", file: file, status: .wouldUpdate),
        ]

        // -- Act --
        let output = AgentSkillInstallationRenderer().render(outcomes)

        // -- Assert --
        #expect(output.contains("Would install: new at"))
        #expect(output.contains("Would update: old at"))
        #expect(output.hasSuffix("Summary: 1 would install, 1 would update"))
    }

    @Test("reports an empty selection rather than writing blank output")
    func reportsNoInstallations() {
        // -- Arrange --
        let renderer = AgentSkillInstallationRenderer()

        // -- Act --
        let output = renderer.render([])

        // -- Assert --
        #expect(output == "No skills to process.")
    }
}
