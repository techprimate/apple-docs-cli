struct TypesListCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let typeCount: Int
    }

    private let client: DocumentationTypeCatalogClient
    private let renderer: DocumentationTypeListRenderer

    init(
        client: DocumentationTypeCatalogClient,
        renderer: DocumentationTypeListRenderer
    ) {
        self.client = client
        self.renderer = renderer
    }

    func run(technology: String) async throws -> Result {
        let types = try await client.fetchTypes(technology: technology)
        return Result(
            output: try renderer.render(types),
            typeCount: types.count
        )
    }
}
