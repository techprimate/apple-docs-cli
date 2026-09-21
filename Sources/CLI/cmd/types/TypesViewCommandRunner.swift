struct TypesViewCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let responseByteCount: Int
    }

    private let client: DocumentationRepository
    private let renderer: TypeDocumentationRenderer

    init(
        client: DocumentationRepository,
        renderer: TypeDocumentationRenderer
    ) {
        self.client = client
        self.renderer = renderer
    }

    func run(name: String, technology: String) async throws -> Result {
        let document = try await client.type(
            named: name,
            technology: technology
        )
        return Result(
            output: try renderer.render(document.page),
            responseByteCount: document.responseByteCount
        )
    }
}
