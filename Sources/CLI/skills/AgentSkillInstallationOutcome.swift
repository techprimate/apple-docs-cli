import Foundation

struct AgentSkillInstallationOutcome: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case installed, updated, unchanged, uninstalled, notInstalled
        case wouldInstall, wouldUpdate, wouldUninstall
    }

    let name: String
    let file: URL
    let status: Status
}

enum AgentSkillInstallationError: Error, Equatable {
    case emptyRoot
    case unmanagedSkill(name: String, removing: Bool)
    case modifiedSkill(name: String, removing: Bool)
    case invalidReceipt(URL)
    case invalidDirectory(URL)
    case invalidFile(URL)
}
