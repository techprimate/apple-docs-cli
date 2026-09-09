import Foundation

struct TechnologiesListCommandResult: Sendable {
    let output: String
    let technologyCount: Int
}

struct TechnologiesListCommandRunner: Sendable {
    private let client: TechnologyCatalogClient
    private let renderer: TechnologyListRenderer

    init(
        client: TechnologyCatalogClient,
        renderer: TechnologyListRenderer
    ) {
        self.client = client
        self.renderer = renderer
    }

    func run() async throws -> TechnologiesListCommandResult {
        let technologies = try await client.fetchTechnologies().sorted {
            $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending
        }
        return TechnologiesListCommandResult(
            output: try renderer.render(technologies),
            technologyCount: technologies.count
        )
    }
}
