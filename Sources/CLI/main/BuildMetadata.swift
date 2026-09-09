enum BuildMetadata {
    static let version = "dev"
    static let commit = "none"
    static let buildDate = "unknown"
    static let environment = "development"

    static let formatted =
        "\(version) (commit: \(commit), built: \(buildDate), environment: \(environment))"
    static let sentryRelease = "apple-docs@\(version)+\(commit)"
}
