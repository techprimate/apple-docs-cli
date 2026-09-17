struct BrowserCatalogState: Equatable, Sendable {
    var aliases: [String: String] = [:]
    var pendingRoots: [String: UInt64] = [:]
    var rootErrors: [String: String] = [:]
    var pendingTypes: [String: UInt64] = [:]
    var types: [String: [DocumentationType]] = [:]
    var typeErrors: [String: String] = [:]
    var pendingTechnologiesID: UInt64?
    var technologies: [Technology] = []
    var technologiesError: String?
}
