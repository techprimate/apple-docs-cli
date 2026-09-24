struct TypesSearchCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let matchCount: Int
        let unavailableCollectionCount: Int
    }

    private let client: DocumentationTypeSearchClient
    private let renderer: DocumentationTypeListRenderer

    init(
        client: DocumentationTypeSearchClient,
        renderer: DocumentationTypeListRenderer
    ) {
        self.client = client
        self.renderer = renderer
    }

    func run(query: String, technology: String) async throws -> Result {
        let result = try await client.searchTypes(query: query, technology: technology)
        return Result(
            output: try renderer.render(result.types),
            matchCount: result.types.count,
            unavailableCollectionCount: result.unavailableCollectionPaths.count
        )
    }
}
