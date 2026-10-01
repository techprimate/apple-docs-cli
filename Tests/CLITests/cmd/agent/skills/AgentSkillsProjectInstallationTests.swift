import Foundation
import Testing

@testable import CLI

@Suite("Agent skills installation scope")
struct AgentSkillsProjectInstallationTests {
    @Test("default installation uses the file manager's home directory")
    func installsInHomeDirectory() throws {
        // -- Arrange --
        let home = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: home) }
        let deps = TestAgentSkillDependencies(fileManager: TestHomeFileManager(home: home))
        let command = try #require(
            CLI.parseAsRoot(["agent", "skills", "install", "apple-docs"]) as? AgentSkillsInstallCommand)

        // -- Act --
        try command.run(deps: deps)

        // -- Assert --
        #expect(
            FileManager.default.fileExists(
                atPath: home.appendingPathComponent(".agents/skills/apple-docs/SKILL.md").path))
    }

    @Test("default uninstall uses the file manager's home directory")
    func uninstallsFromHomeDirectory() throws {
        // -- Arrange --
        let home = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: home) }
        let deps = TestAgentSkillDependencies(fileManager: TestHomeFileManager(home: home))
        let install = try #require(
            CLI.parseAsRoot(["agent", "skills", "install", "apple-docs"]) as? AgentSkillsInstallCommand)
        try install.run(deps: deps)
        let uninstall = try #require(
            CLI.parseAsRoot(["agent", "skills", "uninstall", "apple-docs"]) as? AgentSkillsUninstallCommand)

        // -- Act --
        try uninstall.run(deps: deps)

        // -- Assert --
        #expect(
            !FileManager.default.fileExists(
                atPath: home.appendingPathComponent(".agents/skills/apple-docs/SKILL.md").path))
    }

    @Test("project installation targets the Git root from a nested directory")
    func installsInGitRoot() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("src/nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let deps = TestAgentSkillDependencies(fileManager: TestHomeFileManager(home: root, currentDirectory: nested))
        let command = try #require(
            CLI.parseAsRoot(["agent", "skills", "install", "apple-docs", "--project"])
                as? AgentSkillsInstallCommand)

        // -- Act --
        try command.run(deps: deps)

        // -- Assert --
        #expect(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent(".agents/skills/apple-docs/SKILL.md").path))
        #expect(!FileManager.default.fileExists(atPath: nested.appendingPathComponent(".agents").path))
    }

    @Test("project installation uses the current directory outside Git")
    func installsOutsideGit() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let deps = TestAgentSkillDependencies(fileManager: TestHomeFileManager(home: root, currentDirectory: root))
        let command = try #require(
            CLI.parseAsRoot(["agent", "skills", "install", "apple-docs", "--project"])
                as? AgentSkillsInstallCommand)

        // -- Act --
        try command.run(deps: deps)

        // -- Assert --
        #expect(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent(".agents/skills/apple-docs/SKILL.md").path))
    }

    @Test("project uninstall removes bundled skills from the Git root")
    func uninstallsFromGitRoot() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("src/nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let deps = TestAgentSkillDependencies(fileManager: TestHomeFileManager(home: root, currentDirectory: nested))
        let install = try #require(
            CLI.parseAsRoot(["agent", "skills", "install", "--all", "--project"])
                as? AgentSkillsInstallCommand)
        try install.run(deps: deps)
        let unrelated = root.appendingPathComponent(".agents/skills/custom.txt")
        try Data("keep".utf8).write(to: unrelated)

        // -- Act --
        let uninstall = try #require(
            CLI.parseAsRoot(["agent", "skills", "uninstall", "--all", "--yes", "--project"])
                as? AgentSkillsUninstallCommand)
        try uninstall.run(deps: deps)

        // -- Assert --
        for skill in BundledAgentSkills.all {
            #expect(
                !FileManager.default.fileExists(
                    atPath: root.appendingPathComponent(".agents/skills/\(skill.name)/SKILL.md").path))
        }
        #expect(try String(contentsOf: unrelated, encoding: .utf8) == "keep")
    }

    @Test("project and dir cannot be combined")
    func rejectsAmbiguousInstallationRoot() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // -- Act --
        #expect(throws: (any Error).self) {
            var command = try CLI.parseAsRoot([
                "agent", "skills", "install", "apple-docs", "--project", "--dir", root.path,
            ])
            try command.run()
        }

        // -- Assert --
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test("project uninstall rejects an explicit dir")
    func rejectsAmbiguousUninstallRoot() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let arguments = [
            "agent", "skills", "uninstall", "apple-docs", "--project", "--dir", root.path,
        ]

        // -- Act --
        #expect(throws: (any Error).self) {
            _ = try CLI.parseAsRoot(arguments)
        }

        // -- Assert --
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
    }
}

private struct TestAgentSkillDependencies: AgentSkillInstallerProvider {
    let fileManager: FileManager

    func agentSkillFileManager() -> FileManager { fileManager }

    func agentSkillInstaller() -> AgentSkillInstaller { Dependencies.shared.agentSkillInstaller() }
}

private final class TestHomeFileManager: FileManager {
    let home: URL
    let directory: URL

    init(home: URL, currentDirectory: URL? = nil) {
        self.home = home
        self.directory = currentDirectory ?? home
        super.init()
    }

    override var homeDirectoryForCurrentUser: URL { home }
    override var currentDirectoryPath: String { directory.path }
}
