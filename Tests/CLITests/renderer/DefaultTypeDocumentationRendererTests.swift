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

        let output = try renderer.render(document)

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
        // -- Arrange --
        // This intentionally omits the fields required by the text renderer.
        let rawJSON = "{\"newUpstreamShape\":true}"
        let document = try makeDocument(rawJSON)
        let renderer = DefaultTypeDocumentationRenderer(output: .json)

        // -- Act --
        let output = try renderer.render(document)

        // -- Assert --
        #expect(output == rawJSON)
    }

    private func makeDocument(_ rawJSON: String) throws -> TypeDocumentationDocument {
        TypeDocumentationDocument(data: Data(rawJSON.utf8))
    }
}
