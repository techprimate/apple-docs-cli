import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Skill installation outcomes")
struct AgentSkillInstallationOutcomeTests {
    @Test("returns structured lifecycle outcomes without formatting CLI text")
    func returnsLifecycleOutcomes() throws {
        // -- Arrange --
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))
        let service = DefaultAgentSkillInstallationService(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() })

        // -- Act --
        let preview = try service.install([skill], root: root.path, dryRun: true, force: false)
        let rootExistsAfterPreview = FileManager.default.fileExists(atPath: root.path)
        let installed = try service.install([skill], root: root.path, dryRun: false, force: false)
        let unchanged = try service.install([skill], root: root.path, dryRun: false, force: false)
        let removed = try service.uninstall([skill], root: root.path, dryRun: false)
        let absent = try service.uninstall([skill], root: root.path, dryRun: false)

        // -- Assert --
        #expect(preview.map(\.status) == [.wouldInstall])
        #expect(installed.map(\.status) == [.installed])
        #expect(installed.map(\.name) == ["apple-docs"])
        #expect(installed.first?.file == root.appendingPathComponent("skills/apple-docs/SKILL.md"))
        #expect(unchanged.map(\.status) == [.unchanged])
        #expect(removed.map(\.status) == [.uninstalled])
        #expect(absent.map(\.status) == [.notInstalled])
        #expect(!rootExistsAfterPreview)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("skills/apple-docs/SKILL.md").path))
    }

    @Test("reports an empty installation root as a domain error")
    func rejectsEmptyRoot() throws {
        // -- Arrange --
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))
        let service = DefaultAgentSkillInstallationService(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() })

        // -- Act --
        let install = { try service.install([skill], root: " ", dryRun: false, force: false) }

        // -- Assert --
        #expect(throws: AgentSkillInstallationError.emptyRoot) { try install() }
    }
}
