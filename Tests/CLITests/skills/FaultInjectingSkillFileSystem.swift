import Foundation

@testable import CLI

enum InjectedSkillFailure: Error {
    case filesystem
}

struct FaultInjectingSkillFileSystem: AgentSkillFileSystem {
    enum Operation { case write, remove }
    let operation: Operation
    let filename: String
    var skillName: String?
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
    func removeItem(at url: URL) throws {
        if operation == .remove, matches(url) { throw InjectedSkillFailure.filesystem }
        try fileManager.removeItem(at: url)
    }
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: path)
    }
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        try fileManager.attributesOfItem(atPath: path)
    }
    func readSkillData(at url: URL) throws -> Data { try Data(contentsOf: url) }
    func writeSkillData(_ data: Data, to url: URL) throws {
        if operation == .write, matches(url) { throw InjectedSkillFailure.filesystem }
        try data.write(to: url, options: .atomic)
    }

    private func matches(_ url: URL) -> Bool {
        url.lastPathComponent == filename
            && (skillName == nil || url.deletingLastPathComponent().lastPathComponent == skillName)
    }
}
