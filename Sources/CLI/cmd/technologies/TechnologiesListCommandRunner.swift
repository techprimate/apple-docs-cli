import Foundation

struct TechnologiesListCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let technologyCount: Int
    }

    private let client: DocumentationRepository
    private let renderer: TechnologyListRenderer

    init(
        client: DocumentationRepository,
        renderer: TechnologyListRenderer
    ) {
        self.client = client
        self.renderer = renderer
    }

    func run() async throws -> Result {
        let technologies = try await client.technologies().sorted {
            $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending
        }
        return Result(
            output: try renderer.render(technologies),
            technologyCount: technologies.count
        )
    }
}
