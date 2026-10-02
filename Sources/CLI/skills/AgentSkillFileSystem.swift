import Foundation

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
    }

    extension FileManager: AgentSkillFileSystem {}
#else
    typealias AgentSkillFileSystem = FileManager
#endif
