struct TypesViewCommandRunner: Sendable {
    struct Result: Sendable {
        let output: String
        let responseByteCount: Int
    }

    private let repository: AppleDocumentationRepository
    private let renderer: TypeDocumentationRenderer

    init(
        repository: AppleDocumentationRepository,
        renderer: TypeDocumentationRenderer
    ) {
        self.repository = repository
        self.renderer = renderer
    }

    func run(name: String, technology: String, mode: OutputMode) async throws -> Result {
        let document = try await repository.fetchPage(
            named: name,
            technology: technology
        )
        return Result(
            output: try renderer.render(document.page),
            responseByteCount: document.responseByteCount
        )
    }
}
