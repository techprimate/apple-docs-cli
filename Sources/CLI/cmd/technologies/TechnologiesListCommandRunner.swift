import Foundation

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

    func run() async throws -> String {
        let technologies = try await client.fetchTechnologies().sorted {
            $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending
        }
        return try renderer.render(technologies)
    }
}
