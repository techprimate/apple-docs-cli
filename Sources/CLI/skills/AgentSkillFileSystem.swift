import Foundation

extension FileManager {
    func readSkillData(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func writeSkillData(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}

#if DEBUG
    protocol AgentSkillFileSystem {
        var currentDirectoryPath: String { get }
        var homeDirectoryForCurrentUser: URL { get }
        func fileExists(atPath path: String) -> Bool
        func createDirectory(
            at url: URL, withIntermediateDirectories createIntermediates: Bool,
            attributes: [FileAttributeKey: Any]?
        ) throws
        func removeItem(at url: URL) throws
        func contentsOfDirectory(atPath path: String) throws -> [String]
        func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
        func readSkillData(at url: URL) throws -> Data
        func writeSkillData(_ data: Data, to url: URL) throws
    }

    extension FileManager: AgentSkillFileSystem {}
#else
    typealias AgentSkillFileSystem = FileManager
#endif
