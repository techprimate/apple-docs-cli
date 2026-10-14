import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Interrupted skill installation recovery")
struct AgentSkillInstallationRecoveryTests {
    @Test("recovers a fresh installation interrupted before the receipt write")
    func recoversFreshInstallation() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = fixture("first version")
        let failing = installer(operation: .write, filename: ".apple-docs-managed.json")

        // -- Act --
        #expect(throws: InjectedSkillFailure.self) {
            try failing.install([skill], root: root.path, dryRun: false, force: false)
        }
        let outcome = try healthy.install([skill], root: root.path, dryRun: false, force: false)

        // -- Assert --
        #expect(outcome.map(\.status) == [.unchanged])
        #expect(try Data(contentsOf: file(root)) == Data("first version".utf8))
        #expect(FileManager.default.fileExists(atPath: receipt(root).path))
        #expect(!FileManager.default.fileExists(atPath: pending(root).path))
    }

    @Test("completes an interrupted update before honoring a subsequent uninstall")
    func recoversManagedUpdate() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try healthy.install([fixture("old")], root: root.path, dryRun: false, force: false)
        let unrelated = file(root).deletingLastPathComponent().appendingPathComponent("notes.txt")
        try Data("user notes".utf8).write(to: unrelated)
        let failing = installer(operation: .write, filename: ".apple-docs-managed.json")

        // -- Act --
        #expect(throws: InjectedSkillFailure.self) {
            try failing.install([fixture("new")], root: root.path, dryRun: false, force: true)
        }
        let outcome = try healthy.uninstall([fixture("new")], root: root.path, dryRun: false)

        // -- Assert --
        #expect(outcome.map(\.status) == [.uninstalled])
        #expect(!FileManager.default.fileExists(atPath: file(root).path))
        #expect(!FileManager.default.fileExists(atPath: receipt(root).path))
        #expect(!FileManager.default.fileExists(atPath: pending(root).path))
        #expect(try Data(contentsOf: unrelated) == Data("user notes".utf8))
    }

    @Test("refuses recovery over external edits even with force")
    func preservesExternalEdits() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let failing = installer(operation: .write, filename: ".apple-docs-managed.json")
        #expect(throws: InjectedSkillFailure.self) {
            try failing.install([fixture("bundled")], root: root.path, dryRun: false, force: false)
        }
        try Data("external edits".utf8).write(to: file(root))

        // -- Act --
        #expect(throws: (any Error).self) {
            try healthy.install([fixture("bundled")], root: root.path, dryRun: false, force: true)
        }

        // -- Assert --
        #expect(try Data(contentsOf: file(root)) == Data("external edits".utf8))
        #expect(FileManager.default.fileExists(atPath: pending(root).path))
        #expect(!FileManager.default.fileExists(atPath: receipt(root).path))
    }

    @Test("retries interrupted removal without deleting unrelated files")
    func recoversRemoval() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = fixture("bundled")
        _ = try healthy.install([skill], root: root.path, dryRun: false, force: false)
        let failing = installer(operation: .remove, filename: ".apple-docs-managed.json")

        // -- Act --
        #expect(throws: InjectedSkillFailure.self) { try failing.uninstall([skill], root: root.path, dryRun: false) }
        let outcome = try healthy.uninstall([skill], root: root.path, dryRun: false)

        // -- Assert --
        #expect(outcome.map(\.status) == [.notInstalled])
        #expect(!FileManager.default.fileExists(atPath: file(root).deletingLastPathComponent().path))
    }

    @Test("a dry run leaves an interrupted installation byte-for-byte unchanged")
    func previewsRecoveryWithoutWriting() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = fixture("bundled")
        let failing = installer(operation: .write, filename: ".apple-docs-managed.json")
        #expect(throws: InjectedSkillFailure.self) {
            try failing.install([skill], root: root.path, dryRun: false, force: false)
        }
        let previousJournal = try Data(contentsOf: pending(root))
        let previousContent = try Data(contentsOf: file(root))

        // -- Act --
        let outcomes = try healthy.install([skill], root: root.path, dryRun: true, force: false)
        let output = AgentSkillInstallationRenderer().render(outcomes)

        // -- Assert --
        #expect(output.contains("Would recover pending operation: apple-docs"))
        #expect(try Data(contentsOf: pending(root)) == previousJournal)
        #expect(try Data(contentsOf: file(root)) == previousContent)
        #expect(!FileManager.default.fileExists(atPath: receipt(root).path))
    }

    @Test("retries recovery when journal cleanup was interrupted")
    func retriesJournalCleanup() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = fixture("bundled")
        let failing = installer(operation: .remove, filename: ".apple-docs-pending.json")

        // -- Act --
        #expect(throws: InjectedSkillFailure.self) {
            try failing.install([skill], root: root.path, dryRun: false, force: false)
        }
        let outcome = try healthy.install([skill], root: root.path, dryRun: false, force: false)

        // -- Assert --
        #expect(outcome.map(\.status) == [.unchanged])
        #expect(!FileManager.default.fileExists(atPath: pending(root).path))
        #expect(try Data(contentsOf: file(root)) == Data("bundled".utf8))
    }

    private var healthy: DefaultAgentSkillInstallationService {
        DefaultAgentSkillInstallationService(logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() })
    }

    private func installer(
        operation: FaultInjectingSkillFileSystem.Operation, filename: String
    ) -> DefaultAgentSkillInstallationService {
        DefaultAgentSkillInstallationService(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            fileManager: FaultInjectingSkillFileSystem(operation: operation, filename: filename))
    }

    private func fixture(_ content: String) -> BundledAgentSkill {
        BundledAgentSkill(name: "apple-docs", shortDescription: "Fixture", content: content)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    }
    private func file(_ root: URL) -> URL { root.appendingPathComponent("skills/apple-docs/SKILL.md") }
    private func receipt(_ root: URL) -> URL {
        root.appendingPathComponent("skills/apple-docs/.apple-docs-managed.json")
    }
    private func pending(_ root: URL) -> URL {
        root.appendingPathComponent("skills/apple-docs/.apple-docs-pending.json")
    }
}
