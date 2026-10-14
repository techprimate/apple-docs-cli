import Foundation
import Logging

struct AgentSkillInstallationStore {
    struct Receipt: Codable, Equatable {
        let name: String
        let content: Data
    }

    struct Snapshot: Codable, Equatable {
        var content: Data?
        var receipt: Receipt?
    }

    struct Pending: Codable, Equatable {
        let name: String
        let previous: Snapshot
        let next: Snapshot
    }

    struct Inspection {
        let state: Snapshot
        let pending: Pending?
    }

    let directory: URL
    var file: URL { directory.appendingPathComponent("SKILL.md") }
    private var receiptFile: URL { directory.appendingPathComponent(".apple-docs-managed.json") }
    private var pendingFile: URL { directory.appendingPathComponent(".apple-docs-pending.json") }
    private let name: String
    private let root: URL
    private let fileManager: AgentSkillFileSystem
    private let logger: Logger

    init(name: String, root: URL, fileManager: AgentSkillFileSystem, logger: Logger) {
        self.name = name
        self.root = root
        self.fileManager = fileManager
        self.logger = logger
        directory = root.appendingPathComponent("skills").appendingPathComponent(name)
    }

    func inspect() throws -> Inspection {
        try validateDirectory()
        let current = try snapshot()
        guard let pending = try pending() else { return Inspection(state: current, pending: nil) }
        try validate(current, against: pending)
        return Inspection(state: pending.next, pending: pending)
    }

    func recover(_ inspection: Inspection) throws {
        let current = try inspect()
        guard current.pending == inspection.pending, current.state == inspection.state else {
            throw AgentSkillInstallationError.recoveryConflict(directory)
        }
        if let pending = current.pending {
            try apply(pending)
            logger.info("Recovered interrupted skill operation", metadata: ["skill": .string(name)])
        }
    }

    func update(from previous: Snapshot, to next: Snapshot) throws {
        let current = try inspect()
        guard current.pending == nil, current.state == previous else {
            throw AgentSkillInstallationError.recoveryConflict(directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        let pending = Pending(name: name, previous: previous, next: next)
        try fileManager.writeSkillData(JSONEncoder().encode(pending), to: pendingFile)
        try apply(pending)
    }

    private func apply(_ pending: Pending) throws {
        try validateDirectory()
        guard try self.pending() == pending else { throw AgentSkillInstallationError.recoveryConflict(directory) }
        let current = try snapshot()
        try validate(current, against: pending)
        if current.content != pending.next.content {
            if let content = pending.next.content {
                try fileManager.writeSkillData(content, to: file)
            } else {
                try fileManager.removeItem(at: file)
            }
        }
        if current.receipt != pending.next.receipt {
            if let receipt = pending.next.receipt {
                try fileManager.writeSkillData(JSONEncoder().encode(receipt), to: receiptFile)
            } else {
                try fileManager.removeItem(at: receiptFile)
            }
        }
        guard try snapshot() == pending.next else { throw AgentSkillInstallationError.recoveryConflict(directory) }
        try fileManager.removeItem(at: pendingFile)
        if pending.next == Snapshot(), try fileManager.contentsOfDirectory(atPath: directory.path).isEmpty {
            try fileManager.removeItem(at: directory)
        }
    }

    private func pending() throws -> Pending? {
        guard let data = try regularData(pendingFile) else { return nil }
        guard let pending = try? JSONDecoder().decode(Pending.self, from: data), pending.name == name,
            pending.previous.receipt.map({ $0.name == name }) ?? true,
            pending.previous.content == nil || pending.previous.receipt != nil,
            pending.next == Snapshot()
                || (pending.next.receipt.map { $0.name == name && pending.next.content == $0.content } == true)
        else {
            logger.warning("Invalid pending skill operation", metadata: ["skill": .string(name)])
            throw AgentSkillInstallationError.invalidPendingOperation(pendingFile)
        }
        return pending
    }

    private func validate(_ current: Snapshot, against pending: Pending) throws {
        guard current.content == pending.previous.content || current.content == pending.next.content,
            current.receipt == pending.previous.receipt || current.receipt == pending.next.receipt
        else {
            logger.warning("Refusing recovery over changed skill files", metadata: ["skill": .string(name)])
            throw AgentSkillInstallationError.recoveryConflict(directory)
        }
    }

    private func snapshot() throws -> Snapshot {
        let content = try regularData(file)
        let receipt: Receipt?
        if let data = try regularData(receiptFile) {
            guard let decoded = try? JSONDecoder().decode(Receipt.self, from: data), decoded.name == name else {
                logger.warning("Invalid skill installation receipt", metadata: ["skill": .string(name)])
                throw AgentSkillInstallationError.invalidReceipt(receiptFile)
            }
            receipt = decoded
        } else {
            receipt = nil
        }
        return Snapshot(content: content, receipt: receipt)
    }

    private func validateDirectory() throws {
        var ancestor = directory
        while true {
            if let type = try fileType(ancestor), type != .typeDirectory {
                logger.warning("Refusing symlink or non-directory in skill installation path")
                throw AgentSkillInstallationError.invalidDirectory(ancestor)
            }
            // Ancestors above the selected root may be OS aliases such as /var on macOS.
            if ancestor.path == root.path { return }
            ancestor.deleteLastPathComponent()
        }
    }

    private func regularData(_ url: URL) throws -> Data? {
        guard let type = try fileType(url) else { return nil }
        guard type == .typeRegular else {
            logger.warning("Refusing symlink or non-regular skill installation file")
            throw AgentSkillInstallationError.invalidFile(url)
        }
        return try fileManager.readSkillData(at: url)
    }

    private func fileType(_ url: URL) throws -> FileAttributeType? {
        do {
            return try fileManager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }
}
