import Foundation
import Testing

@testable import CLI

@Suite("Agent skills updates")
struct AgentSkillsUpdateTests {
    @Test("update refreshes only managed installations and leaves uninstalled skills absent")
    func updatesInstalledSkills() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try installPreviousVersion(at: root)
        let unmanaged = skillFile(root, name: "apple-docs-support")
        try write("user skill", to: unmanaged)

        // -- Act --
        try run(["update", "--dir", root.path])
        try run(["update", "--dir", root.path])

        // -- Assert --
        #expect(try String(contentsOf: skillFile(root), encoding: .utf8) == BundledAgentSkills.all[0].content)
        #expect(try String(contentsOf: unmanaged, encoding: .utf8) == "user skill")
        #expect(!FileManager.default.fileExists(atPath: skillFile(root, name: "apple-docs-terms").path))
    }

    @Test("update dry run preserves the previous version")
    func previewsUpdate() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try installPreviousVersion(at: root)

        // -- Act --
        try run(["update", "--dry-run", "--dir", root.path])

        // -- Assert --
        #expect(try String(contentsOf: skillFile(root), encoding: .utf8) == "previous version")
    }

    @Test("update without installations does not create a root")
    func updatesEmptyInstallation() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // -- Act --
        try run(["update", "--dir", root.path])

        // -- Assert --
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test("update leaves missing managed files absent")
    func skipsMissingManagedFiles() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try installPreviousVersion(at: root)
        try FileManager.default.removeItem(at: skillFile(root))

        // -- Act --
        try run(["update", "--dir", root.path])

        // -- Assert --
        #expect(!FileManager.default.fileExists(atPath: skillFile(root).path))
        #expect(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("skills/apple-docs/.apple-docs-managed.json").path))
    }

    @Test("named updates do not update other installed skills")
    func updatesNamedSkills() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try installPreviousVersion(at: root)
        try installPreviousVersion(at: root, name: "apple-docs-support")

        // -- Act --
        try run(["update", "apple-docs", "apple-docs", "--dir", root.path])

        // -- Assert --
        #expect(try String(contentsOf: skillFile(root), encoding: .utf8) == BundledAgentSkills.all[0].content)
        #expect(
            try String(contentsOf: skillFile(root, name: "apple-docs-support"), encoding: .utf8) == "previous version")
    }

    @Test("update preflights local edits before changing any installed skill")
    func protectsEditsDuringUpdate() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try installPreviousVersion(at: root)
        try installPreviousVersion(at: root, name: "apple-docs-support")
        let edited = skillFile(root, name: "apple-docs-support")
        try write("local edits", to: edited)

        // -- Act --
        do {
            try run(["update", "--dir", root.path])
            Issue.record("Expected update to refuse local edits")
        } catch {
            #expect(CLI.message(for: error).contains("install apple-docs-support --force"))
        }

        // -- Assert --
        #expect(try String(contentsOf: skillFile(root), encoding: .utf8) == "previous version")
        #expect(try String(contentsOf: edited, encoding: .utf8) == "local edits")
    }

    private func installPreviousVersion(at root: URL, name: String = "apple-docs") throws {
        try write("previous version", to: skillFile(root, name: name))
        let receipt = AgentSkillInstallationStore.Receipt(name: name, content: Data("previous version".utf8))
        try JSONEncoder().encode(receipt).write(
            to: root.appendingPathComponent("skills/\(name)/.apple-docs-managed.json"))
    }

    private func run(_ arguments: [String]) throws {
        var command = try CLI.parseAsRoot(["agent", "skills"] + arguments)
        try command.run()
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
    }

    private func skillFile(_ root: URL, name: String = "apple-docs") -> URL {
        root.appendingPathComponent("skills/\(name)/SKILL.md")
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }
}
