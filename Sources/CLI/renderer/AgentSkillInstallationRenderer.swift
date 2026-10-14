struct AgentSkillInstallationRenderer {
    func render(_ outcomes: [AgentSkillInstallationOutcome]) -> String {
        outcomes.map { outcome in
            let action: String
            switch outcome.status {
            case .installed, .updated:
                action = "Installed: \(outcome.name) at \(outcome.file.path)"
            case .wouldInstall, .wouldUpdate:
                action = "Would install: \(outcome.name) at \(outcome.file.path)"
            case .unchanged: action = "Unchanged: \(outcome.name)"
            case .uninstalled: action = "Uninstalled: \(outcome.name)"
            case .wouldUninstall: action = "Would uninstall: \(outcome.name)"
            case .notInstalled: action = "Not installed: \(outcome.name)"
            }
            let recovery = outcome.requiresRecovery ? "Would recover pending operation: \(outcome.name)\n" : ""
            return recovery + action
        }.joined(separator: "\n")
    }
}
