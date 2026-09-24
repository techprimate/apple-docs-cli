struct DefaultTypeDocumentationRenderer: Sendable {
    typealias Output = OutputFormat

    let output: Output
    var audience: OutputAudience = .human

    func render(_ document: TypeDocumentationDocument) throws -> String {
        if output == .json {
            return RawJSONTypeDocumentationRenderer().render(document)
        }
        let page = try DocumentationPageDecoder().decode(document.data, destination: document.destination)
        let presentation = DocumentationPresenter().page(page, audience: audience)
        return audience == .agent
            ? AgentDocumentationRenderer().render(presentation)
            : TextTypeDocumentationRenderer().render(page)
    }
}
