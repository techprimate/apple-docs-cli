struct TypesListCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let typeCount: Int
    }

    private let client: DocumentationTypeCatalogRepository
    private let renderer: DocumentationTypeListRenderer

    init(
        client: DocumentationTypeCatalogRepository,
        renderer: DocumentationTypeListRenderer
    ) {
        self.client = client
        self.renderer = renderer
    }

    func run(technology: String, mode: OutputMode) async throws -> Result {
        let types = try await client.fetchTypes(technology: technology)
        return Result(
            output: try renderer.render(types),
            typeCount: types.count
        )
    }
}
