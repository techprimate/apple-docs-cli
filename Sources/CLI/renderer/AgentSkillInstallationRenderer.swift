struct AgentSkillInstallationRenderer {
    func render(_ outcomes: [AgentSkillInstallationOutcome]) -> String {
        outcomes.map { outcome in
            switch outcome.status {
            case .installed, .updated:
                return "Installed: \(outcome.name) at \(outcome.file.path)"
            case .wouldInstall, .wouldUpdate:
                return "Would install: \(outcome.name) at \(outcome.file.path)"
            case .unchanged: return "Unchanged: \(outcome.name)"
            case .uninstalled: return "Uninstalled: \(outcome.name)"
            case .wouldUninstall: return "Would uninstall: \(outcome.name)"
            case .notInstalled: return "Not installed: \(outcome.name)"
            }
        }.joined(separator: "\n")
    }
}
