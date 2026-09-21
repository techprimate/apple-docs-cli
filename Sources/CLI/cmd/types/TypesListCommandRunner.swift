struct TypesListCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let typeCount: Int
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

    func run(technology: String) async throws -> Result {
        let types = try await client.types(technology: technology)
        return Result(
            output: try renderer.render(types),
            typeCount: types.count
        )
    }
}
