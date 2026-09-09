struct TypesViewCommandResult: Sendable {
    let output: String
    let responseByteCount: Int
}

struct TypesViewCommandRunner: Sendable {
    private let client: AppleDocumentationClient
    private let renderer: TypeDocumentationRenderer

    init(
        client: AppleDocumentationClient,
        renderer: TypeDocumentationRenderer
    ) {
        self.client = client
        self.renderer = renderer
    }

    func run(name: String, technology: String) async throws -> TypesViewCommandResult {
        let document = try await client.fetchType(
            named: name,
            technology: technology
        )
        return TypesViewCommandResult(
            output: renderer.render(document),
            responseByteCount: document.data.count
        )
    }
}
