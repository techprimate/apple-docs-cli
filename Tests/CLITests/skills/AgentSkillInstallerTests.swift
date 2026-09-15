import ArgumentParser
import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Agent skill installer logging")
struct AgentSkillInstallerTests {
    @available(macOS 15, *)
    @Test("logs installation, unchanged files, removal, and absent installations")
    func logsLifecycle() throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let installer = AgentSkillInstaller(logger: recorder.logger())
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))

        // -- Act --
        _ = try installer.install([skill], root: root.path, dryRun: false, force: false)
        let installed = try String(contentsOf: skillFile(root), encoding: .utf8)
        _ = try installer.install([skill], root: root.path, dryRun: false, force: false)
        _ = try installer.uninstall([skill], root: root.path, dryRun: false)
        _ = try installer.uninstall([skill], root: root.path, dryRun: false)

        // -- Assert --
        #expect(installed == skill.content)
        #expect(!FileManager.default.fileExists(atPath: skillFile(root).path))
        let events = recorder.events
        let installedEvent = try #require(events.first { $0.message.description == "Installed skill" })
        #expect(installedEvent.level == .info)
        #expect(installedEvent.metadata?["skill"]?.description == "apple-docs")
        #expect(events.contains { $0.level == .debug && $0.message.description == "Skill installation unchanged" })
        #expect(events.contains { $0.level == .info && $0.message.description == "Uninstalled skill" })
        #expect(events.contains { $0.level == .debug && $0.message.description == "Skill not installed" })
        #expect(events.contains { $0.level == .trace })
        #expect(!events.contains { $0.level >= .warning })
        for event in events {
            let log = "\(event.message) \(event.metadata ?? [:])"
            #expect(!log.contains(root.path))
            #expect(!log.contains(skill.content))
        }
    }

    @available(macOS 15, *)
    @Test("distinguishes dry runs from actual filesystem changes")
    func logsDryRuns() throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let installer = AgentSkillInstaller(logger: recorder.logger())
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))

        // -- Act --
        _ = try installer.install([skill], root: root.path, dryRun: true, force: false)
        let rootExistsAfterPreview = FileManager.default.fileExists(atPath: root.path)
        let previewEvents = recorder.events
        _ = try installer.install([skill], root: root.path, dryRun: false, force: false)
        let beforeUninstallPreview = recorder.events.count
        _ = try installer.uninstall([skill], root: root.path, dryRun: true)

        // -- Assert --
        #expect(!rootExistsAfterPreview)
        #expect(previewEvents.contains { $0.level == .info && $0.message.description == "Would install skill" })
        #expect(!previewEvents.contains { $0.message.description == "Installed skill" })
        #expect(FileManager.default.fileExists(atPath: skillFile(root).path))
        let removalEvents = recorder.events.dropFirst(beforeUninstallPreview)
        #expect(removalEvents.contains { $0.level == .info && $0.message.description == "Would uninstall skill" })
        #expect(!removalEvents.contains { $0.message.description == "Uninstalled skill" })
    }

    @available(macOS 15, *)
    @Test("warns about unmanaged files without overwriting or leaking their content", arguments: [false, true])
    func logsUnmanagedConflict(uninstall: Bool) throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let installer = AgentSkillInstaller(logger: recorder.logger())
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))
        try write("private user skill", to: skillFile(root))

        // -- Act --
        #expect(throws: ValidationError.self) {
            if uninstall {
                _ = try installer.uninstall([skill], root: root.path, dryRun: false)
            } else {
                _ = try installer.install([skill], root: root.path, dryRun: false, force: true)
            }
        }

        // -- Assert --
        #expect(try String(contentsOf: skillFile(root), encoding: .utf8) == "private user skill")
        #expect(recorder.events.contains { $0.level == .warning })
        #expect(!recorder.events.contains { $0.level >= .error || $0.level == .info })
        for event in recorder.events {
            let log = "\(event.message) \(event.metadata ?? [:])"
            #expect(!log.contains("private user skill"))
            #expect(!log.contains(root.path))
        }
    }

    @available(macOS 15, *)
    @Test("logs forced replacement of modified managed files")
    func logsForcedReplacement() throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let installer = AgentSkillInstaller(logger: recorder.logger())
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))
        _ = try installer.install([skill], root: root.path, dryRun: false, force: false)
        try write("local edits", to: skillFile(root))
        let previousEventCount = recorder.events.count

        // -- Act --
        _ = try installer.install([skill], root: root.path, dryRun: false, force: true)

        // -- Assert --
        #expect(try String(contentsOf: skillFile(root), encoding: .utf8) == skill.content)
        let events = recorder.events.dropFirst(previousEventCount)
        #expect(events.contains { $0.level == .notice && $0.message.description == "Replacing modified managed skill" })
        #expect(events.contains { $0.level == .info && $0.message.description == "Installed skill" })
    }

    @available(macOS 15, *)
    @Test("warns about invalid receipts before changing installed files")
    func logsInvalidReceipt() throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let installer = AgentSkillInstaller(logger: recorder.logger())
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))
        _ = try installer.install([skill], root: root.path, dryRun: false, force: false)
        try write(
            "private invalid receipt", to: root.appendingPathComponent("skills/apple-docs/.apple-docs-managed.json"))
        let previousEventCount = recorder.events.count

        // -- Act --
        #expect(throws: ValidationError.self) {
            try installer.uninstall([skill], root: root.path, dryRun: false)
        }

        // -- Assert --
        #expect(try String(contentsOf: skillFile(root), encoding: .utf8) == skill.content)
        let events = recorder.events.dropFirst(previousEventCount)
        #expect(
            events.contains { $0.level == .warning && $0.message.description == "Invalid skill installation receipt" })
        #expect(!events.contains { $0.level >= .error || $0.level == .info })
    }

    @available(macOS 15, *)
    @Test("logs filesystem failures as errors without exposing the installation path", arguments: [false, true])
    func logsFilesystemFailure(uninstall: Bool) throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let installer = AgentSkillInstaller(logger: recorder.logger())
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let invalidRoot = root.appendingPathComponent(String(repeating: "x", count: 300))
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))

        // -- Act --
        #expect(throws: (any Error).self) {
            if uninstall {
                _ = try installer.uninstall([skill], root: invalidRoot.path, dryRun: false)
            } else {
                _ = try installer.install([skill], root: invalidRoot.path, dryRun: false, force: false)
            }
        }

        // -- Assert --
        #expect(recorder.events.contains { $0.level == .error })
        #expect(!recorder.events.contains { $0.level == .info })
        #expect(!recorder.events.contains { "\($0.message) \($0.metadata ?? [:])".contains(root.path) })
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    }

    private func skillFile(_ root: URL) -> URL {
        root.appendingPathComponent("skills/apple-docs/SKILL.md")
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }
}
