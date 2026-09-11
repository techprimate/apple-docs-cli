import Foundation
import Testing

@testable import CLI

@Suite("Agent skills installation")
struct AgentSkillsInstallationTests {
    @Test("installs selected skills and is idempotent")
    func installsSelectedSkills() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // -- Act --
        try run(["install", "apple-docs", "--dir", root.path])
        try run(["install", "apple-docs", "--dir", root.path])

        // -- Assert --
        let installed = try String(contentsOf: skillFile(root), encoding: .utf8)
        #expect(installed == BundledAgentSkills.skill(named: "apple-docs")?.content)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("skills").path)
                == ["apple-docs"])
    }

    @Test("installs and uninstalls the entire bundle")
    func installsAllSkills() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // -- Act --
        try run(["install", "--all", "--dir", root.path])
        let installed = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("skills").path)
        try run(["uninstall", "--all", "--yes", "--dir", root.path])

        // -- Assert --
        #expect(Set(installed) == Set(BundledAgentSkills.all.map(\.name)))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("skills").path).isEmpty)
    }

    @Test("dry run does not create an installation root")
    func previewsInstall() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // -- Act --
        try run(["install", "--all", "--dry-run", "--dir", root.path])

        // -- Assert --
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test("uninstall dry run preserves installed files without bulk confirmation")
    func previewsUninstall() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try run(["install", "--all", "--dir", root.path])

        // -- Act --
        try run(["uninstall", "--all", "--dry-run", "--dir", root.path])

        // -- Assert --
        #expect(FileManager.default.fileExists(atPath: skillFile(root).path))
    }

    @Test(
        "rejects invalid selection before writing",
        arguments: [
            ["install"], ["install", "--all", "apple-docs"],
            ["install", "apple-docs", "unknown"], ["install", "../escape"],
            ["uninstall"], ["uninstall", "--all"], ["uninstall", "--all", "apple-docs", "--yes"],
            ["uninstall", "unknown"],
        ])
    func rejectsInvalidSelection(arguments: [String]) throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // -- Act --
        #expect(throws: (any Error).self) {
            try run(arguments + ["--dir", root.path])
        }

        // -- Assert --
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test("force only replaces files from a managed installation")
    func protectsUnmanagedFiles() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("user skill", to: skillFile(root))

        // -- Act --
        #expect(throws: (any Error).self) {
            try run(["install", "apple-docs", "--force", "--dir", root.path])
        }
        #expect(throws: (any Error).self) {
            try run(["uninstall", "apple-docs", "--dir", root.path])
        }

        // -- Assert --
        #expect(try String(contentsOf: skillFile(root), encoding: .utf8) == "user skill")
    }

    @Test("protects modified managed files unless installation is forced")
    func protectsModifiedFiles() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try run(["install", "apple-docs", "--dir", root.path])
        try Data("local edits".utf8).write(to: skillFile(root))

        // -- Act --
        #expect(throws: (any Error).self) {
            try run(["install", "apple-docs", "--dir", root.path])
        }
        #expect(throws: (any Error).self) {
            try run(["uninstall", "apple-docs", "--dir", root.path])
        }

        // -- Assert --
        #expect(try String(contentsOf: skillFile(root), encoding: .utf8) == "local edits")
        try run(["install", "apple-docs", "--force", "--dir", root.path])
        #expect(
            try String(contentsOf: skillFile(root), encoding: .utf8)
                == BundledAgentSkills.skill(named: "apple-docs")?.content)
    }

    @Test("uninstall preserves unrelated files and skills")
    func preservesUnrelatedFiles() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try run(["install", "apple-docs", "--dir", root.path])
        let notes = root.appendingPathComponent("skills/apple-docs/notes.txt")
        let other = root.appendingPathComponent("skills/custom/SKILL.md")
        try write("notes", to: notes)
        try write("custom", to: other)

        // -- Act --
        try run(["uninstall", "apple-docs", "--dir", root.path])
        try run(["uninstall", "apple-docs", "--dir", root.path])

        // -- Assert --
        #expect(!FileManager.default.fileExists(atPath: skillFile(root).path))
        #expect(try String(contentsOf: notes, encoding: .utf8) == "notes")
        #expect(try String(contentsOf: other, encoding: .utf8) == "custom")
    }

    @Test("preflights every selected skill before writing")
    func preflightsConflicts() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let lastSkill = try #require(BundledAgentSkills.all.last)
        let conflict = root.appendingPathComponent("skills/\(lastSkill.name)/SKILL.md")
        try write("unmanaged", to: conflict)

        // -- Act --
        #expect(throws: (any Error).self) {
            try run(["install", "--all", "--dir", root.path])
        }

        // -- Assert --
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("skills").path)
                == [lastSkill.name])
        #expect(try String(contentsOf: conflict, encoding: .utf8) == "unmanaged")
    }

    @Test("uninstalls only named skills and accepts duplicate names")
    func selectsMultipleSkills() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try run(["install", "--all", "--dir", root.path])

        // -- Act --
        try run([
            "uninstall", "apple-docs", "apple-docs-discover-api", "apple-docs", "--dir", root.path,
        ])

        // -- Assert --
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("skills").path)
                == ["apple-docs-check-availability"])
    }

    @Test("preflights all removals before deleting any skill")
    func preflightsRemovalConflicts() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try run(["install", "--all", "--dir", root.path])
        let lastSkill = try #require(BundledAgentSkills.all.last)
        let modified = root.appendingPathComponent("skills/\(lastSkill.name)/SKILL.md")
        try write("local edits", to: modified)

        // -- Act --
        #expect(throws: (any Error).self) {
            try run(["uninstall", "--all", "--yes", "--dir", root.path])
        }

        // -- Assert --
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("skills").path).count
                == BundledAgentSkills.all.count)
        #expect(FileManager.default.fileExists(atPath: skillFile(root).path))
        #expect(try String(contentsOf: modified, encoding: .utf8) == "local edits")
    }

    @Test(
        "refuses invalid ownership receipts",
        arguments: [
            "not JSON", "{\"name\":\"other-skill\",\"content\":\"\"}",
        ])
    func rejectsInvalidReceipts(content: String) throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try run(["install", "apple-docs", "--dir", root.path])
        let receipt = root.appendingPathComponent("skills/apple-docs/.apple-docs-managed.json")
        try write(content, to: receipt)
        let original = try Data(contentsOf: skillFile(root))

        // -- Act --
        #expect(throws: (any Error).self) {
            try run(["install", "apple-docs", "--force", "--dir", root.path])
        }
        #expect(throws: (any Error).self) {
            try run(["uninstall", "apple-docs", "--dir", root.path])
        }

        // -- Assert --
        #expect(try Data(contentsOf: skillFile(root)) == original)
        #expect(try String(contentsOf: receipt, encoding: .utf8) == content)
    }

    @Test(
        "rejects symlinks instead of writing or deleting outside the installation",
        arguments: [
            "", "skills", "skills/apple-docs", "skills/apple-docs/SKILL.md",
            "skills/apple-docs/.apple-docs-managed.json",
        ])
    func rejectsSymlinks(relativePath: String) throws {
        // -- Arrange --
        let root = temporaryRoot()
        let outside = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try write("outside", to: outside.appendingPathComponent("sentinel"))
        let link = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        // -- Act --
        #expect(throws: (any Error).self) {
            try run(["install", "apple-docs", "--force", "--dir", root.path])
        }
        #expect(throws: (any Error).self) {
            try run(["uninstall", "apple-docs", "--dir", root.path])
        }

        // -- Assert --
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path) == ["sentinel"])
    }

    private func run(_ arguments: [String]) throws {
        var command = try CLI.parseAsRoot(["agent", "skills"] + arguments)
        try command.run()
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
    }

    private func skillFile(_ root: URL) -> URL {
        root.appendingPathComponent("skills/apple-docs/SKILL.md")
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }
}
