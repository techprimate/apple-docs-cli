struct DefaultTechnologyListRenderer: Sendable {
    enum Output: Sendable {
        case table
        case json
    }

    private let output: Output
    private let audience: OutputAudience

    init(output: Output, audience: OutputAudience = .human) {
        self.output = output
        self.audience = audience
    }

    func render(_ technologies: [Technology]) throws -> String {
        let presentation = DocumentationPresenter().technologies(technologies, audience: audience)
        switch output {
        case .table:
            return audience == .agent
                ? AgentDocumentationRenderer().render(presentation)
                : HumanDocumentationRenderer().render(presentation)
        case .json:
            return try StructuredDocumentationRenderer().render(presentation)
        }
    }
}
