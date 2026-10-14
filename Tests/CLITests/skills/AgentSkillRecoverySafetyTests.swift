import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Skill recovery safety")
struct AgentSkillRecoverySafetyTests {
    @Test("preflights all selected skills before recovering an earlier interrupted operation")
    func preflightsBeforeRecovery() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = fixture("first")
        let second = fixture("second")
        let failing = DefaultAgentSkillInstallationService(
            logger: logger,
            fileManager: FaultInjectingSkillFileSystem(operation: .write, filename: ".apple-docs-managed.json"))
        #expect(throws: InjectedSkillFailure.self) {
            try failing.install([first], root: root.path, dryRun: false, force: false)
        }
        let pending = root.appendingPathComponent("skills/first/.apple-docs-pending.json")
        let previousJournal = try Data(contentsOf: pending)
        let unmanaged = root.appendingPathComponent("skills/second/SKILL.md")
        try FileManager.default.createDirectory(
            at: unmanaged.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("user skill".utf8).write(to: unmanaged)

        // -- Act --
        #expect(throws: AgentSkillInstallationError.unmanagedSkill(name: "second", removing: false)) {
            try healthy.install([first, second], root: root.path, dryRun: false, force: true)
        }

        // -- Assert --
        #expect(try Data(contentsOf: pending) == previousJournal)
        #expect(
            !FileManager.default.fileExists(
                atPath: root.appendingPathComponent("skills/first/.apple-docs-managed.json").path))
        #expect(try Data(contentsOf: unmanaged) == Data("user skill".utf8))
    }

    @Test("refuses symlinked operation journals without touching their targets")
    func rejectsJournalSymlink() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = fixture("skill")
        _ = try healthy.install([skill], root: root.path, dryRun: false, force: false)
        let outside = root.appendingPathComponent("outside.txt")
        try Data("private content".utf8).write(to: outside)
        let pending = root.appendingPathComponent("skills/skill/.apple-docs-pending.json")
        try FileManager.default.createSymbolicLink(at: pending, withDestinationURL: outside)

        // -- Act --
        #expect(throws: AgentSkillInstallationError.invalidFile(pending)) {
            try healthy.install([skill], root: root.path, dryRun: false, force: true)
        }

        // -- Assert --
        #expect(try Data(contentsOf: outside) == Data("private content".utf8))
        #expect(try Data(contentsOf: root.appendingPathComponent("skills/skill/SKILL.md")) == Data("skill".utf8))
    }

    @Test("refuses malformed journals instead of inferring ownership")
    func rejectsMalformedJournal() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = fixture("skill")
        _ = try healthy.install([skill], root: root.path, dryRun: false, force: false)
        let pending = root.appendingPathComponent("skills/skill/.apple-docs-pending.json")
        try Data("{}".utf8).write(to: pending)

        // -- Act --
        #expect(throws: AgentSkillInstallationError.invalidPendingOperation(pending)) {
            try healthy.uninstall([skill], root: root.path, dryRun: false)
        }

        // -- Assert --
        #expect(try Data(contentsOf: pending) == Data("{}".utf8))
        #expect(try Data(contentsOf: root.appendingPathComponent("skills/skill/SKILL.md")) == Data("skill".utf8))
    }

    @Test("an external receipt edit prevents recovery even when the content is unchanged")
    func preservesReceiptEdits() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = fixture("skill")
        let failing = DefaultAgentSkillInstallationService(
            logger: logger,
            fileManager: FaultInjectingSkillFileSystem(operation: .remove, filename: ".apple-docs-pending.json"))
        #expect(throws: InjectedSkillFailure.self) {
            try failing.install([skill], root: root.path, dryRun: false, force: false)
        }
        let receipt = root.appendingPathComponent("skills/skill/.apple-docs-managed.json")
        let edited = Data(#"{"name":"skill","content":"ZXh0ZXJuYWw="}"#.utf8)
        try edited.write(to: receipt)

        // -- Act --
        #expect(throws: AgentSkillInstallationError.recoveryConflict(receipt.deletingLastPathComponent())) {
            try healthy.install([skill], root: root.path, dryRun: false, force: true)
        }

        // -- Assert --
        #expect(try Data(contentsOf: receipt) == edited)
        #expect(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("skills/skill/.apple-docs-pending.json").path))
    }

    private var logger: Logger { Logger(label: "test") { _ in SwiftLogNoOpLogHandler() } }
    private var healthy: DefaultAgentSkillInstallationService { DefaultAgentSkillInstallationService(logger: logger) }
    private func fixture(_ name: String) -> BundledAgentSkill {
        BundledAgentSkill(name: name, shortDescription: "Fixture", content: name)
    }
    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    }
}
