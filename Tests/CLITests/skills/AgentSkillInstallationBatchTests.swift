import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Skill batch failures")
struct AgentSkillInstallationBatchTests {
    @Test("reports completed skills when a later installation is interrupted")
    func preservesCompletedOutcomes() throws {
        // -- Arrange --
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let skills = ["first", "second"].map { BundledAgentSkill(name: $0, shortDescription: "Fixture", content: $0) }
        let service = DefaultAgentSkillInstallationService(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            fileManager: FaultInjectingSkillFileSystem(
                operation: .write, filename: ".apple-docs-managed.json", skillName: "second"))

        // -- Act --
        do {
            _ = try service.install(skills, root: root.path, dryRun: false, force: false)
            Issue.record("Expected the second installation to fail")
        } catch let failure as AgentSkillBatchFailure {
            // -- Assert --
            #expect(failure.completed.map(\.name) == ["first"])
            #expect(failure.completed.map(\.status) == [.installed])
            #expect(failure.failedSkill == "second")
            #expect(failure.underlying is InjectedSkillFailure)
            #expect(try Data(contentsOf: root.appendingPathComponent("skills/first/SKILL.md")) == Data("first".utf8))
            #expect(
                FileManager.default.fileExists(
                    atPath: root.appendingPathComponent("skills/second/.apple-docs-pending.json").path))
        }
    }
}
