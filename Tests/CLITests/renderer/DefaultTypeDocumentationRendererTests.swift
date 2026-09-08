import Foundation
import Testing

@testable import CLI

@Suite("Default type documentation renderer")
struct DefaultTypeDocumentationRendererTests {
    @Test("renders text output")
    func rendersText() throws {
        let rawJSON = """
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
            """
        let document = try makeDocument(rawJSON)
        let renderer = DefaultTypeDocumentationRenderer(output: .text)

        let output = renderer.render(document)

        #expect(
            output == """
                MXHangDiagnostic
                Class · MetricKit

                A diagnostic report.
                """
        )
    }

    @Test("returns Apple's DocC JSON unchanged")
    func rendersRawJSON() throws {
        let rawJSON = """
            {
              "abstract": [],
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
            """
        let document = try makeDocument(rawJSON)
        let renderer = DefaultTypeDocumentationRenderer(output: .json)

        let output = renderer.render(document)

        #expect(output == rawJSON)
    }

    private func makeDocument(_ rawJSON: String) throws -> TypeDocumentationDocument {
        let data = Data(rawJSON.utf8)
        let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)
        return TypeDocumentationDocument(data: data, page: page)
    }
}
