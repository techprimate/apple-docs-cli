struct DefaultTypeDocumentationRenderer: Sendable {
    enum Output: Sendable {
        case text
        case json
    }

    private let output: Output

    init(output: Output) {
        self.output = output
    }

    func render(_ document: TypeDocumentationDocument) -> String {
        switch output {
        case .text:
            return TextTypeDocumentationRenderer().render(document.page)
        case .json:
            return RawJSONTypeDocumentationRenderer().render(document)
        }
    }
}
