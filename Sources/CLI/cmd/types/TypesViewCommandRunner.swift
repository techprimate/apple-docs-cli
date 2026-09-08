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

    func run(name: String, technology: String) async throws -> String {
        let document = try await client.fetchType(
            named: name,
            technology: technology
        )
        return renderer.render(document)
    }
}
