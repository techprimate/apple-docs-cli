import ArgumentParser
import Foundation
import Logging

/// Owns only SKILL.md and its installation receipt, never an entire skill directory.
struct AgentSkillInstaller {
    private struct Receipt: Codable {
        let name: String
        let content: Data
    }

    private struct Installation {
        let skill: BundledAgentSkill
        let directory: URL
        let file: URL
        let receiptFile: URL
        let content: Data?
        let receipt: Receipt?
    }

    private let fileManager = FileManager.default
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
        logger.trace("Initialized agent skill installer")
    }

    func install(
        _ skills: [BundledAgentSkill], root: String, dryRun: Bool, force: Bool
    ) throws -> String {
        logger.debug(
            "Installing agent skills",
            metadata: [
                "count": .stringConvertible(skills.count), "dry_run": .stringConvertible(dryRun),
                "force": .stringConvertible(force),
            ])
        do {
            let installations = try inspect(skills, root: root)
            for installation in installations {
                if let content = installation.content {
                    guard installation.receipt != nil else {
                        logger.warning(
                            "Refusing to overwrite unmanaged skill",
                            metadata: ["skill": .string(installation.skill.name)])
                        throw ValidationError("Refusing to overwrite unmanaged skill '\(installation.skill.name)'.")
                    }
                    if content != Data(installation.skill.content.utf8), !force {
                        logger.warning(
                            "Managed skill differs, force required",
                            metadata: ["skill": .string(installation.skill.name)])
                        throw ValidationError(
                            "Skill '\(installation.skill.name)' differs. Use --force to replace the managed file."
                        )
                    }
                }
            }
            logger.debug(
                "Skill installation preflight completed", metadata: ["count": .stringConvertible(installations.count)])
            return try installations.map { try install($0, dryRun: dryRun, force: force) }.joined(separator: "\n")
        } catch {
            if !(error is ValidationError) {
                logger.error(
                    "Skill installation failed", metadata: ["error_type": .string(String(reflecting: type(of: error)))])
            }
            throw error
        }
    }

    func uninstall(_ skills: [BundledAgentSkill], root: String, dryRun: Bool) throws -> String {
        logger.debug(
            "Uninstalling agent skills",
            metadata: [
                "count": .stringConvertible(skills.count), "dry_run": .stringConvertible(dryRun),
            ])
        do {
            let installations = try inspect(skills, root: root)
            for installation in installations {
                if let content = installation.content {
                    guard let receipt = installation.receipt else {
                        logger.warning(
                            "Refusing to remove unmanaged skill", metadata: ["skill": .string(installation.skill.name)])
                        throw ValidationError("Refusing to remove unmanaged skill '\(installation.skill.name)'.")
                    }
                    guard content == receipt.content else {
                        logger.warning(
                            "Refusing to remove edited skill", metadata: ["skill": .string(installation.skill.name)])
                        throw ValidationError(
                            "Skill '\(installation.skill.name)' was edited. Back up and restore it before uninstalling."
                        )
                    }
                }
            }
            logger.debug(
                "Skill removal preflight completed", metadata: ["count": .stringConvertible(installations.count)])
            return try installations.map { try uninstall($0, dryRun: dryRun) }.joined(separator: "\n")
        } catch {
            if !(error is ValidationError) {
                logger.error(
                    "Skill removal failed", metadata: ["error_type": .string(String(reflecting: type(of: error)))])
            }
            throw error
        }
    }

    private func install(_ installation: Installation, dryRun: Bool, force: Bool) throws -> String {
        let metadata: Logger.Metadata = ["skill": .string(installation.skill.name)]
        let content = Data(installation.skill.content.utf8)
        if installation.content == content, installation.receipt?.content == content {
            logger.debug("Skill installation unchanged", metadata: metadata)
            return "Unchanged: \(installation.skill.name)"
        }
        if force, let previousContent = installation.content, previousContent != content {
            logger.notice(
                dryRun ? "Would replace modified managed skill" : "Replacing modified managed skill", metadata: metadata
            )
        }
        if !dryRun {
            try fileManager.createDirectory(at: installation.directory, withIntermediateDirectories: true)
            try content.write(to: installation.file, options: .atomic)
            let receipt = Receipt(name: installation.skill.name, content: content)
            try JSONEncoder().encode(receipt).write(to: installation.receiptFile, options: .atomic)
        }
        logger.info(dryRun ? "Would install skill" : "Installed skill", metadata: metadata)
        return "\(dryRun ? "Would install" : "Installed"): \(installation.skill.name) at \(installation.file.path)"
    }

    private func uninstall(_ installation: Installation, dryRun: Bool) throws -> String {
        let metadata: Logger.Metadata = ["skill": .string(installation.skill.name)]
        guard installation.receipt != nil else {
            logger.debug("Skill not installed", metadata: metadata)
            return "Not installed: \(installation.skill.name)"
        }
        if !dryRun {
            if installation.content != nil {
                try fileManager.removeItem(at: installation.file)
            }
            try fileManager.removeItem(at: installation.receiptFile)
            if try fileManager.contentsOfDirectory(atPath: installation.directory.path).isEmpty {
                try fileManager.removeItem(at: installation.directory)
                logger.trace("Removed empty skill directory", metadata: metadata)
            } else {
                logger.debug("Preserved unrelated skill directory contents", metadata: metadata)
            }
        }
        logger.info(dryRun ? "Would uninstall skill" : "Uninstalled skill", metadata: metadata)
        return "\(dryRun ? "Would uninstall" : "Uninstalled"): \(installation.skill.name)"
    }

    private func inspect(_ skills: [BundledAgentSkill], root: String) throws -> [Installation] {
        logger.trace("Inspecting skill installations", metadata: ["count": .stringConvertible(skills.count)])
        guard !root.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.warning("Empty skill installation root")
            throw ValidationError("The installation directory must not be empty.")
        }
        let rootURL = URL(fileURLWithPath: (root as NSString).expandingTildeInPath).standardizedFileURL
        return try skills.map { skill in
            logger.debug("Inspecting skill installation", metadata: ["skill": .string(skill.name)])
            let directory = rootURL.appendingPathComponent("skills").appendingPathComponent(skill.name)
            let file = directory.appendingPathComponent("SKILL.md")
            let receiptFile = directory.appendingPathComponent(".apple-docs-managed.json")
            try validateDirectory(directory, root: rootURL)
            let content = try readRegularFile(file)
            let receiptData = try readRegularFile(receiptFile)
            let receipt: Receipt?
            if let receiptData {
                guard let decoded = try? JSONDecoder().decode(Receipt.self, from: receiptData),
                    decoded.name == skill.name
                else {
                    logger.warning("Invalid skill installation receipt", metadata: ["skill": .string(skill.name)])
                    throw ValidationError("Invalid apple-docs installation receipt at '\(receiptFile.path)'.")
                }
                logger.trace("Validated skill installation receipt", metadata: ["skill": .string(skill.name)])
                receipt = decoded
            } else {
                logger.trace("No skill installation receipt", metadata: ["skill": .string(skill.name)])
                receipt = nil
            }
            return Installation(
                skill: skill, directory: directory, file: file, receiptFile: receiptFile,
                content: content, receipt: receipt
            )
        }
    }

    private func validateDirectory(_ directory: URL, root: URL) throws {
        logger.trace("Validating skill directory ancestors")
        var ancestor = directory
        while true {
            if let type = try fileType(ancestor), type != .typeDirectory {
                logger.warning("Refusing symlink or non-directory in skill installation path")
                throw ValidationError("Expected a directory, not a symlink or other file, at '\(ancestor.path)'.")
            }
            // Ancestors above the user-selected root may be OS aliases such as /var on macOS.
            if ancestor.path == root.path { return }
            ancestor.deleteLastPathComponent()
        }
    }

    private func readRegularFile(_ url: URL) throws -> Data? {
        logger.trace("Reading skill installation file", metadata: ["file": .string(url.lastPathComponent)])
        guard let type = try fileType(url) else { return nil }
        guard type == .typeRegular else {
            logger.warning(
                "Refusing symlink or non-regular skill installation file",
                metadata: ["file": .string(url.lastPathComponent)])
            throw ValidationError("Expected a regular file, not a symlink or directory, at '\(url.path)'.")
        }
        return try Data(contentsOf: url)
    }

    private func fileType(_ url: URL) throws -> FileAttributeType? {
        logger.trace("Inspecting filesystem entry type")
        do {
            return try fileManager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            logger.trace("Filesystem entry absent")
            return nil
        }
    }
}
