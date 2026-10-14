import Foundation
import Testing

@testable import CLI

@Suite("Types view command runner")
struct TypesViewCommandRunnerTests {
    @Test("fetches and renders the requested type")
    func fetchesAndRendersType() async throws {
        // -- Arrange --
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
        let document = TypeDocumentationDocument(
            data: data, destination: .init(technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic"))
        let client = RequestedTypeClient(
            expectedName: "MXHangDiagnostic",
            expectedTechnology: "MetricKit",
            document: document
        )
        let renderer = RequestedTypeRenderer(
            output: "rendered documentation"
        )
        let runner = TypesViewCommandRunner(repository: client, renderer: renderer)

        // -- Act --
        let result = try await runner.run(
            name: "MXHangDiagnostic",
            technology: "MetricKit",
            mode: .oneShot(audience: .human, format: .text)
        )

        // -- Assert --
        #expect(result.output == "rendered documentation")
        #expect(result.responseByteCount == data.count)
    }
}

private struct RequestedTypeClient: AppleDocumentationRepository {
    let expectedName: String
    let expectedTechnology: String
    let document: TypeDocumentationDocument

    func fetchPage(named name: String, technology: String) async throws -> LoadedDocumentationPage {
        guard name == expectedName, technology == expectedTechnology else {
            throw TestDocumentationClientError.unexpectedRequest
        }
        return LoadedDocumentationPage(
            page: try DocumentationPageDecoder().decode(document.data, destination: document.destination),
            responseByteCount: document.data.count)
    }
}

private struct RequestedTypeRenderer: TypeDocumentationRenderer {
    let output: String

    func render(_ document: DocumentationPage) -> String {
        guard document.title == "MXHangDiagnostic" else {
            return "unexpected document"
        }
        return output
    }
}

private enum TestDocumentationClientError: Error {
    case unexpectedRequest
}
