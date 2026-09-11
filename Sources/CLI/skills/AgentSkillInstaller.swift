import ArgumentParser
import Foundation

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

    func install(
        _ skills: [BundledAgentSkill], root: String, dryRun: Bool, force: Bool
    ) throws -> String {
        let installations = try inspect(skills, root: root)
        for installation in installations {
            if let content = installation.content {
                guard installation.receipt != nil else {
                    throw ValidationError("Refusing to overwrite unmanaged skill '\(installation.skill.name)'.")
                }
                if content != Data(installation.skill.content.utf8), !force {
                    throw ValidationError(
                        "Skill '\(installation.skill.name)' differs. Use --force to replace the managed file."
                    )
                }
            }
        }

        return try installations.map { installation in
            let content = Data(installation.skill.content.utf8)
            if installation.content == content, installation.receipt?.content == content {
                return "Unchanged: \(installation.skill.name)"
            }
            if !dryRun {
                try fileManager.createDirectory(at: installation.directory, withIntermediateDirectories: true)
                try content.write(to: installation.file, options: .atomic)
                let receipt = Receipt(name: installation.skill.name, content: content)
                try JSONEncoder().encode(receipt).write(to: installation.receiptFile, options: .atomic)
            }
            return "\(dryRun ? "Would install" : "Installed"): \(installation.skill.name) at \(installation.file.path)"
        }.joined(separator: "\n")
    }

    func uninstall(_ skills: [BundledAgentSkill], root: String, dryRun: Bool) throws -> String {
        let installations = try inspect(skills, root: root)
        for installation in installations {
            if let content = installation.content {
                guard let receipt = installation.receipt else {
                    throw ValidationError("Refusing to remove unmanaged skill '\(installation.skill.name)'.")
                }
                guard content == receipt.content else {
                    throw ValidationError(
                        "Skill '\(installation.skill.name)' was edited. Back up and restore it before uninstalling."
                    )
                }
            }
        }

        return try installations.map { installation in
            guard installation.receipt != nil else {
                return "Not installed: \(installation.skill.name)"
            }
            if !dryRun {
                if installation.content != nil {
                    try fileManager.removeItem(at: installation.file)
                }
                try fileManager.removeItem(at: installation.receiptFile)
                if try fileManager.contentsOfDirectory(atPath: installation.directory.path).isEmpty {
                    try fileManager.removeItem(at: installation.directory)
                }
            }
            return "\(dryRun ? "Would uninstall" : "Uninstalled"): \(installation.skill.name)"
        }.joined(separator: "\n")
    }

    private func inspect(_ skills: [BundledAgentSkill], root: String) throws -> [Installation] {
        guard !root.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("The installation directory must not be empty.")
        }
        let rootURL = URL(fileURLWithPath: (root as NSString).expandingTildeInPath).standardizedFileURL
        return try skills.map { skill in
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
                    throw ValidationError("Invalid apple-docs installation receipt at '\(receiptFile.path)'.")
                }
                receipt = decoded
            } else {
                receipt = nil
            }
            return Installation(
                skill: skill, directory: directory, file: file, receiptFile: receiptFile,
                content: content, receipt: receipt
            )
        }
    }

    private func validateDirectory(_ directory: URL, root: URL) throws {
        var ancestor = directory
        while true {
            if let type = try fileType(ancestor), type != .typeDirectory {
                throw ValidationError("Expected a directory, not a symlink or other file, at '\(ancestor.path)'.")
            }
            // Ancestors above the user-selected root may be OS aliases such as /var on macOS.
            if ancestor.path == root.path { return }
            ancestor.deleteLastPathComponent()
        }
    }

    private func readRegularFile(_ url: URL) throws -> Data? {
        guard let type = try fileType(url) else { return nil }
        guard type == .typeRegular else {
            throw ValidationError("Expected a regular file, not a symlink or directory, at '\(url.path)'.")
        }
        return try Data(contentsOf: url)
    }

    private func fileType(_ url: URL) throws -> FileAttributeType? {
        do {
            return try fileManager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }
}
