struct DefaultTypeDocumentationRenderer: Sendable {
    typealias Output = OutputFormat

    let output: Output
    var audience: OutputAudience = .human

    func render(_ page: DocumentationPage) throws -> String {
        let presentation = DocumentationPresenter().page(page, audience: audience)
        switch output {
        case .json:
            return try StructuredDocumentationRenderer().render(presentation)
        case .text:
            return audience == .agent
                ? AgentDocumentationRenderer().render(presentation)
                : HumanDocumentationRenderer().render(presentation)
        }
    }
}
