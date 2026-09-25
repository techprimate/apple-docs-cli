struct DefaultDocumentationTypeListRenderer: Sendable {
    enum Output: Sendable {
        case table
        case json
    }

    private let output: Output
    private let audience: OutputAudience
    private let technology: String

    init(output: Output, audience: OutputAudience = .human, technology: String = "") {
        self.output = output
        self.audience = audience
        self.technology = technology
    }

    func render(_ types: [DocumentationType]) throws -> String {
        let presentation = DocumentationPresenter().symbols(types, technology: technology, audience: audience)
        switch output {
        case .table:
            return audience == .agent
                ? AgentDocumentationRenderer().render(presentation, technology: technology)
                : HumanDocumentationRenderer().render(presentation)
        case .json:
            return try StructuredDocumentationRenderer().render(presentation)
        }
    }
}
