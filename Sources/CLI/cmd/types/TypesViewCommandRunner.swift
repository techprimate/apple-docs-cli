struct TypesViewCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let responseByteCount: Int
    }

    private let client: AppleDocumentationClient
    private let renderer: TypeDocumentationRenderer

    init(
        client: AppleDocumentationClient,
        renderer: TypeDocumentationRenderer
    ) {
        self.client = client
        self.renderer = renderer
    }

    func run(name: String, technology: String) async throws -> Result {
        let document = try await client.fetchType(
            named: name,
            technology: technology
        )
        return Result(
            output: try renderer.render(document),
            responseByteCount: document.data.count
        )
    }
}
