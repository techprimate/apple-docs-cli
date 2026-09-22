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
                Symbol kind: class

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
                Symbol kind: struct

                  The Swift package manifest representation.
                """
        )
    }

    @Test("renders articles without module or symbol metadata")
    func rendersArticleWithoutSymbolMetadata() throws {
        // -- Arrange --
        let rawJSON = """
            {
              "kind": "article",
              "abstract": [{"text": "Distribute binaries in Swift packages.", "type": "text"}],
              "metadata": {
                "role": "article",
                "roleHeading": "Article",
                "title": "Distributing binary frameworks as Swift packages"
              },
              "primaryContentSections": [{
                "kind": "content",
                "content": [
                  {"type": "heading", "level": 2, "text": "Overview"},
                  {
                    "type": "paragraph",
                    "inlineContent": [{"type": "text", "text": "Create an XCFramework bundle."}]
                  }
                ]
              }],
              "references": {}
            }
            """
        let document = try makeDocument(rawJSON)
        let renderer = DefaultTypeDocumentationRenderer(output: .text)

        // -- Act --
        let output = try renderer.render(document)

        // -- Assert --
        #expect(output.hasPrefix("Distributing binary frameworks as Swift packages\n"))
        #expect(output.contains("\nArticle\n\n  Distribute binaries in Swift packages."))
        #expect(output.contains("Overview\n────────\n\n  Create an XCFramework bundle."))
        #expect(!output.contains("Symbol kind:"))
        #expect(!output.contains("Availability"))
        #expect(!output.contains("Declaration"))
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
