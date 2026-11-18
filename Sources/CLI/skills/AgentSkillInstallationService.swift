import Foundation
import Logging

/// Owns only SKILL.md, its receipt, and its recovery journal, never an entire skill directory.
struct DefaultAgentSkillInstallationService {
    private struct Installation {
        let skill: BundledAgentSkill
        let store: AgentSkillInstallationStore
        let inspection: AgentSkillInstallationStore.Inspection

        var content: Data? { inspection.state.content }
        var receipt: AgentSkillInstallationStore.Receipt? { inspection.state.receipt }
        var file: URL { store.file }
    }

    private let fileManager: AgentSkillFileSystem
    private let logger: Logger

    init(logger: Logger, fileManager: AgentSkillFileSystem = FileManager.default) {
        self.fileManager = fileManager
        self.logger = logger
        logger.trace("Initialized agent skill installer")
    }

    func install(
        _ skills: [BundledAgentSkill], root: String, dryRun: Bool, force: Bool
    ) throws -> [AgentSkillInstallationOutcome] {
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
                        throw AgentSkillInstallationError.unmanagedSkill(name: installation.skill.name, removing: false)
                    }
                    if content != Data(installation.skill.content.utf8), !force {
                        logger.warning(
                            "Managed skill differs, force required",
                            metadata: ["skill": .string(installation.skill.name)])
                        throw AgentSkillInstallationError.modifiedSkill(name: installation.skill.name, removing: false)
                    }
                }
            }
            logger.debug(
                "Skill installation preflight completed", metadata: ["count": .stringConvertible(installations.count)])
            return try execute(installations) { try install($0, dryRun: dryRun, force: force) }
        } catch {
            if !(error is AgentSkillInstallationError) {
                logger.error(
                    "Skill installation failed", metadata: ["error_type": .string(String(reflecting: type(of: error)))])
            }
            throw error
        }
    }

    func list(_ skills: [BundledAgentSkill], root: String) throws -> [AgentSkillInstallationStatus] {
        try inspect(skills, root: root).map { installation in
            let status: AgentSkillInstallationStatus.Status
            if let content = installation.content {
                if let receipt = installation.receipt {
                    if content != receipt.content {
                        status = .modified
                    } else {
                        status = content == Data(installation.skill.content.utf8) ? .installed : .updateAvailable
                    }
                } else {
                    status = .unmanaged
                }
            } else {
                status = installation.receipt == nil ? .notInstalled : .missing
            }
            return AgentSkillInstallationStatus(
                skill: installation.skill, file: installation.file, status: status,
                requiresRecovery: installation.inspection.pending != nil)
        }
    }

    func update(
        _ skills: [BundledAgentSkill], root: String, dryRun: Bool
    ) throws -> [AgentSkillInstallationOutcome] {
        let installations = try inspect(skills, root: root).filter { $0.receipt != nil && $0.content != nil }
        for installation in installations {
            guard installation.content == installation.receipt?.content else {
                throw AgentSkillInstallationError.modifiedSkill(name: installation.skill.name, removing: false)
            }
        }
        return try execute(installations) { try install($0, dryRun: dryRun, force: false) }
    }

    func uninstall(
        _ skills: [BundledAgentSkill], root: String, dryRun: Bool
    ) throws -> [AgentSkillInstallationOutcome] {
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
                        throw AgentSkillInstallationError.unmanagedSkill(name: installation.skill.name, removing: true)
                    }
                    guard content == receipt.content else {
                        logger.warning(
                            "Refusing to remove edited skill", metadata: ["skill": .string(installation.skill.name)])
                        throw AgentSkillInstallationError.modifiedSkill(name: installation.skill.name, removing: true)
                    }
                }
            }
            logger.debug(
                "Skill removal preflight completed", metadata: ["count": .stringConvertible(installations.count)])
            return try execute(installations) { try uninstall($0, dryRun: dryRun) }
        } catch {
            if !(error is AgentSkillInstallationError) {
                logger.error(
                    "Skill removal failed", metadata: ["error_type": .string(String(reflecting: type(of: error)))])
            }
            throw error
        }
    }

    private func execute(
        _ installations: [Installation], operation: (Installation) throws -> AgentSkillInstallationOutcome
    ) throws -> [AgentSkillInstallationOutcome] {
        var completed: [AgentSkillInstallationOutcome] = []
        for installation in installations {
            do {
                completed.append(try operation(installation))
            } catch {
                guard !completed.isEmpty else { throw error }
                throw AgentSkillBatchFailure(
                    completed: completed, failedSkill: installation.skill.name, underlying: error)
            }
        }
        return completed
    }

    private func install(
        _ installation: Installation, dryRun: Bool, force: Bool
    ) throws -> AgentSkillInstallationOutcome {
        let metadata: Logger.Metadata = ["skill": .string(installation.skill.name)]
        let content = Data(installation.skill.content.utf8)
        if !dryRun { try installation.store.recover(installation.inspection) }
        if installation.content == content, installation.receipt?.content == content {
            logger.debug("Skill installation unchanged", metadata: metadata)
            return AgentSkillInstallationOutcome(
                name: installation.skill.name, file: installation.file, status: .unchanged,
                requiresRecovery: dryRun && installation.inspection.pending != nil)
        }
        if force, let previousContent = installation.content, previousContent != content {
            logger.notice(
                dryRun ? "Would replace modified managed skill" : "Replacing modified managed skill", metadata: metadata
            )
        }
        if !dryRun {
            try installation.store.update(
                from: installation.inspection.state,
                to: .init(content: content, receipt: .init(name: installation.skill.name, content: content)))
        }
        let updating = installation.content != nil
        if updating {
            logger.info(dryRun ? "Would update skill" : "Updated skill", metadata: metadata)
        } else {
            logger.info(dryRun ? "Would install skill" : "Installed skill", metadata: metadata)
        }
        return AgentSkillInstallationOutcome(
            name: installation.skill.name, file: installation.file,
            status: dryRun ? (updating ? .wouldUpdate : .wouldInstall) : (updating ? .updated : .installed),
            requiresRecovery: dryRun && installation.inspection.pending != nil)
    }

    private func uninstall(_ installation: Installation, dryRun: Bool) throws -> AgentSkillInstallationOutcome {
        let metadata: Logger.Metadata = ["skill": .string(installation.skill.name)]
        if !dryRun { try installation.store.recover(installation.inspection) }
        guard installation.receipt != nil else {
            logger.debug("Skill not installed", metadata: metadata)
            return AgentSkillInstallationOutcome(
                name: installation.skill.name, file: installation.file, status: .notInstalled,
                requiresRecovery: dryRun && installation.inspection.pending != nil)
        }
        if !dryRun {
            try installation.store.update(from: installation.inspection.state, to: .init())
        }
        logger.info(dryRun ? "Would uninstall skill" : "Uninstalled skill", metadata: metadata)
        return AgentSkillInstallationOutcome(
            name: installation.skill.name, file: installation.file, status: dryRun ? .wouldUninstall : .uninstalled,
            requiresRecovery: dryRun && installation.inspection.pending != nil)
    }

    private func inspect(_ skills: [BundledAgentSkill], root: String) throws -> [Installation] {
        logger.trace("Inspecting skill installations", metadata: ["count": .stringConvertible(skills.count)])
        guard !root.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.warning("Empty skill installation root")
            throw AgentSkillInstallationError.emptyRoot
        }
        let rootURL = URL(fileURLWithPath: (root as NSString).expandingTildeInPath).standardizedFileURL
        return try skills.map { skill in
            logger.debug("Inspecting skill installation", metadata: ["skill": .string(skill.name)])
            let store = AgentSkillInstallationStore(
                name: skill.name, root: rootURL, fileManager: fileManager, logger: logger)
            return Installation(skill: skill, store: store, inspection: try store.inspect())
        }
    }
}

#if DEBUG
    protocol AgentSkillInstallationService {
        func list(_ skills: [BundledAgentSkill], root: String) throws -> [AgentSkillInstallationStatus]
        func update(_ skills: [BundledAgentSkill], root: String, dryRun: Bool) throws -> [AgentSkillInstallationOutcome]
        func install(_ skills: [BundledAgentSkill], root: String, dryRun: Bool, force: Bool) throws
            -> [AgentSkillInstallationOutcome]
        func uninstall(_ skills: [BundledAgentSkill], root: String, dryRun: Bool) throws
            -> [AgentSkillInstallationOutcome]
    }

    extension DefaultAgentSkillInstallationService: AgentSkillInstallationService {}

    protocol AgentSkillInstallationServiceProvider {
        associatedtype Service: AgentSkillInstallationService
        associatedtype FileSystem: AgentSkillFileSystem
        func agentSkillInstallationService() -> Service
        func agentSkillFileManager() -> FileSystem
    }

    extension Dependencies: AgentSkillInstallationServiceProvider {}
#else
    typealias AgentSkillInstallationService = DefaultAgentSkillInstallationService
#endif
