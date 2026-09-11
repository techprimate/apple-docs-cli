import Foundation
import Testing

@testable import CLI

@Suite("Default type documentation renderer")
struct DefaultTypeDocumentationRendererTests {
    @Test("renders text output")
    func rendersText() throws {
        // -- Arrange --
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

        // -- Act --
        let output = try renderer.render(document)

        // -- Assert --
        #expect(
            output == """
                MXHangDiagnostic
                ━━━━━━━━━━━━━━━━
                Class · MetricKit

                  A diagnostic report.
                """
        )
    }

    @Test("renders text when platform metadata is omitted")
    func rendersTextWithoutPlatforms() throws {
        // -- Arrange --
        let rawJSON = """
            {
              "abstract": [{"text": "The Swift package manifest representation.", "type": "text"}],
              "metadata": {
                "modules": [{"name": "PackageDescription"}],
                "roleHeading": "Structure",
                "symbolKind": "struct",
                "title": "Package"
              },
              "primaryContentSections": [],
              "references": {}
            }
            """
        let document = try makeDocument(rawJSON)
        let renderer = DefaultTypeDocumentationRenderer(output: .text)

        // -- Act --
        let output = try renderer.render(document)

        // -- Assert --
        #expect(
            output == """
                Package
                ━━━━━━━
                Structure · PackageDescription

                  The Swift package manifest representation.
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
