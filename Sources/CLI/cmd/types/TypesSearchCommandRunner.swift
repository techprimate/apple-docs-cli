struct TypesSearchCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let matchCount: Int
        let unavailableCollectionCount: Int
    }

    private let client: DocumentationRepository
    private let renderer: DocumentationTypeListRenderer

    init(
        client: DocumentationRepository,
        renderer: DocumentationTypeListRenderer
    ) {
        self.client = client
        self.renderer = renderer
    }

    func run(query: String, technology: String) async throws -> Result {
        let result = try await client.search(query: query, technology: technology)
        return Result(
            output: try renderer.render(result.types),
            matchCount: result.types.count,
            unavailableCollectionCount: result.unavailableCollectionPaths.count
        )
    }
}
