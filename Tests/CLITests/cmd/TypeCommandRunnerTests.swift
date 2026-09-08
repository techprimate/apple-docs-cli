import Foundation
import Testing

@testable import CLI

@Suite("Type command runner")
struct TypeCommandRunnerTests {
    @Test("fetches and renders the requested type")
    func fetchesAndRendersType() async throws {
        let data = Data(
            """
            {
              "abstract": [{"text": "A diagnostic report.", "type": "text"}],
              "metadata": {
                "modules": [{"name": "MetricKit"}],
                "platforms": [],
                "roleHeading": "Class",
                "symbolKind": "class",
                "title": "MXHangDiagnostic"
              },
              "primaryContentSections": [],
              "references": {}
            }
            """.utf8
        )
        let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)
        let document = TypeDocumentationDocument(data: data, page: page)
        let client = RequestedTypeClient(
            expectedName: "MXHangDiagnostic",
            expectedTechnology: "MetricKit",
            document: document
        )
        let renderer = RequestedTypeRenderer(
            expectedTitle: "MXHangDiagnostic",
            output: "rendered documentation"
        )
        let runner = TypeCommandRunner(client: client, renderer: renderer)

        let output = try await runner.run(
            name: "MXHangDiagnostic",
            technology: "MetricKit"
        )

        #expect(output == "rendered documentation")
    }
}

private struct RequestedTypeClient: AppleDocumentationClient {
    let expectedName: String
    let expectedTechnology: String
    let document: TypeDocumentationDocument

    func fetchType(named name: String, technology: String) async throws -> TypeDocumentationDocument {
        guard name == expectedName, technology == expectedTechnology else {
            throw TestDocumentationClientError.unexpectedRequest
        }
        return document
    }
}

private struct RequestedTypeRenderer: TypeDocumentationRenderer {
    let expectedTitle: String
    let output: String

    func render(_ document: TypeDocumentationDocument) -> String {
        guard document.page.metadata.title == expectedTitle else {
            return "unexpected document"
        }
        return output
    }
}

private enum TestDocumentationClientError: Error {
    case unexpectedRequest
}
