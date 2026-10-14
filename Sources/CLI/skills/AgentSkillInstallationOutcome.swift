import Foundation

struct AgentSkillInstallationOutcome: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case installed, updated, unchanged, uninstalled, notInstalled
        case wouldInstall, wouldUpdate, wouldUninstall
    }

    let name: String
    let file: URL
    let status: Status
    var requiresRecovery = false
}

enum AgentSkillInstallationError: Error, Equatable {
    case emptyRoot
    case unmanagedSkill(name: String, removing: Bool)
    case modifiedSkill(name: String, removing: Bool)
    case invalidReceipt(URL)
    case invalidDirectory(URL)
    case invalidFile(URL)
    case invalidPendingOperation(URL)
    case recoveryConflict(URL)
}

struct AgentSkillBatchFailure: Error {
    let completed: [AgentSkillInstallationOutcome]
    let failedSkill: String
    let underlying: any Error
}
