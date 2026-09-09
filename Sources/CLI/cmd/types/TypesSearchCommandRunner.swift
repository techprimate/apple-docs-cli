struct TypesSearchCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let matchCount: Int
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
        let types = try await client.searchTypes(query: query, technology: technology)
        return Result(
            output: try renderer.render(types),
            matchCount: types.count
        )
    }
}
