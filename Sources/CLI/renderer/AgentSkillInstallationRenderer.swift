struct AgentSkillInstallationRenderer {
    func render(_ outcomes: [AgentSkillInstallationOutcome]) -> String {
        guard !outcomes.isEmpty else { return "No skills to process." }
        let lines = outcomes.map { outcome in
            let action: String
            switch outcome.status {
            case .installed:
                action = "Installed: \(outcome.name) at \(outcome.file.path)"
            case .updated:
                action = "Updated: \(outcome.name) at \(outcome.file.path)"
            case .wouldInstall:
                action = "Would install: \(outcome.name) at \(outcome.file.path)"
            case .wouldUpdate:
                action = "Would update: \(outcome.name) at \(outcome.file.path)"
            case .unchanged: action = "Unchanged: \(outcome.name)"
            case .uninstalled: action = "Uninstalled: \(outcome.name)"
            case .wouldUninstall: action = "Would uninstall: \(outcome.name)"
            case .notInstalled: action = "Not installed: \(outcome.name)"
            }
            let recovery = outcome.requiresRecovery ? "Would recover pending operation: \(outcome.name)\n" : ""
            return recovery + action
        }
        let labels: [(AgentSkillInstallationOutcome.Status, String)] = [
            (.installed, "installed"), (.updated, "updated"), (.unchanged, "unchanged"),
            (.uninstalled, "uninstalled"), (.notInstalled, "not installed"),
            (.wouldInstall, "would install"), (.wouldUpdate, "would update"), (.wouldUninstall, "would uninstall"),
        ]
        let counts = labels.compactMap { status, label -> String? in
            let count = outcomes.filter { $0.status == status }.count
            return count == 0 ? nil : "\(count) \(label)"
        }
        return (lines + ["Summary: " + counts.joined(separator: ", ")]).joined(separator: "\n")
    }

    func renderList(_ installations: [AgentSkillInstallationStatus]) -> [String] {
        installations.map { installation in
            let recovery = installation.requiresRecovery ? " (pending recovery)" : ""
            return "\(installation.skill.name)\t\(installation.status.rawValue)\(recovery)\t\(installation.file.path)"
                + "\t\(installation.skill.shortDescription)"
        }
    }
}
