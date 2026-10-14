struct DefaultDocumentationSearchRenderer: Sendable {
    let output: OutputFormat
    var audience: OutputAudience = .human

    func render(_ result: DocumentationSearchResult) throws -> String {
        let presentation = DocumentationPresenter().search(result, audience: audience)
        switch output {
        case .json: return try StructuredDocumentationRenderer().render(presentation)
        case .text:
            return audience == .agent
                ? AgentDocumentationRenderer().render(presentation.types, technology: presentation.technology)
                : HumanDocumentationRenderer().render(presentation.types)
        }
    }
}
