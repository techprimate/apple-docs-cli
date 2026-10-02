import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Agent skill file access")
struct AgentSkillFileSystemTests {
    @Test("installation uses injected atomic file writes")
    func usesInjectedWriter() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))
        let service = DefaultAgentSkillInstallationService(
            logger: Logger(label: "test"), fileManager: FailingDataAccessFileSystem(denied: .write))
        let file = root.appendingPathComponent("skills/apple-docs/SKILL.md")

        // -- Act --
        #expect(throws: DataAccessDenied.self) {
            _ = try service.install([skill], root: root.path, dryRun: false, force: false)
        }

        // -- Assert --
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("uninstallation uses injected file reads before deleting")
    func usesInjectedReader() throws {
        // -- Arrange --
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = try #require(BundledAgentSkills.skill(named: "apple-docs"))
        let installed = DefaultAgentSkillInstallationService(logger: Logger(label: "test"))
        _ = try installed.install([skill], root: root.path, dryRun: false, force: false)
        let service = DefaultAgentSkillInstallationService(
            logger: Logger(label: "test"), fileManager: FailingDataAccessFileSystem(denied: .read))
        let file = root.appendingPathComponent("skills/apple-docs/SKILL.md")

        // -- Act --
        #expect(throws: DataAccessDenied.self) {
            _ = try service.uninstall([skill], root: root.path, dryRun: false)
        }

        // -- Assert --
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
    }
}

private enum DataAccessDenied: Error {
    case read, write
}

private struct FailingDataAccessFileSystem: AgentSkillFileSystem {
    let denied: DataAccessDenied
    private let fileManager = FileManager.default

    var currentDirectoryPath: String { fileManager.currentDirectoryPath }
    var homeDirectoryForCurrentUser: URL { fileManager.homeDirectoryForCurrentUser }
    func fileExists(atPath path: String) -> Bool { fileManager.fileExists(atPath: path) }
    func createDirectory(
        at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?
    ) throws {
        try fileManager.createDirectory(
            at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }
    func removeItem(at url: URL) throws { try fileManager.removeItem(at: url) }
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: path)
    }
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        try fileManager.attributesOfItem(atPath: path)
    }
    func readSkillData(at url: URL) throws -> Data {
        if denied == .read { throw DataAccessDenied.read }
        return try Data(contentsOf: url)
    }
    func writeSkillData(_ data: Data, to url: URL) throws {
        if denied == .write { throw DataAccessDenied.write }
        try data.write(to: url, options: .atomic)
    }
}
