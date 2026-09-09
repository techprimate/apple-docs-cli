import Foundation

struct DefaultTypeDocumentationRenderer: Sendable {
    enum Output: Sendable {
        case text
        case json
    }

    private let output: Output

    init(output: Output) {
        self.output = output
    }

    func render(_ document: TypeDocumentationDocument) throws -> String {
        switch output {
        case .text:
            let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: document.data)
            return TextTypeDocumentationRenderer().render(page)
        case .json:
            return RawJSONTypeDocumentationRenderer().render(document)
        }
    }
}
