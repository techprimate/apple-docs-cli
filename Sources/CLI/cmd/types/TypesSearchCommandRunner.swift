struct TypesSearchCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let matchCount: Int
        let unavailableCollectionCount: Int
    }

    private let client: DocumentationTypeSearchRepository
    private let renderer: DocumentationSearchRenderer

    init(
        client: DocumentationTypeSearchRepository,
        renderer: DocumentationSearchRenderer
    ) {
        self.client = client
        self.renderer = renderer
    }

    func run(query: String, technology: String, mode: OutputMode) async throws -> Result {
        let result = try await client.searchTypes(query: query, technology: technology)
        return Result(
            output: try renderer.render(result),
            matchCount: result.types.count,
            unavailableCollectionCount: result.unavailableCollections.count
        )
    }
}
