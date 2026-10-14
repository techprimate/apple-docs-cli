import Foundation

extension AgentSkillInstallationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyRoot: return "The installation directory must not be empty."
        case .unmanagedSkill(let name, let removing):
            return "Refusing to \(removing ? "remove" : "overwrite") unmanaged skill '\(name)'."
        case .modifiedSkill(let name, let removing):
            return removing
                ? "Skill '\(name)' was edited. Back up and restore it before uninstalling."
                : "Skill '\(name)' differs. Use --force to replace the managed file."
        case .invalidReceipt(let url): return "Invalid apple-docs installation receipt at '\(url.path)'."
        case .invalidDirectory(let url):
            return "Expected a directory, not a symlink or other file, at '\(url.path)'."
        case .invalidFile(let url):
            return "Expected a regular file, not a symlink or directory, at '\(url.path)'."
        }
    }
}
