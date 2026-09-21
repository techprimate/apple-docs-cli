import Foundation
import Testing

@testable import CLI

@Suite("Default type documentation renderer")
struct DefaultTypeDocumentationRendererTests {
    @Test("renders sparse collection pages")
    func rendersSparseCollection() throws {
        // -- Arrange --
        let document = try DocumentationPageDecoder().decode(
            Data(#"{"kind":"article","metadata":{"title":"SwiftUI","role":"collection"}}"#.utf8),
            destination: .init(technology: "swiftui", path: "/documentation/swiftui"))
        let renderer = DefaultTypeDocumentationRenderer(output: .text)

        // -- Act --
        let output = try renderer.render(document)

        // -- Assert --
        #expect(output.hasPrefix("SwiftUI\n"))
        #expect(output.contains("Collection"))
    }

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

                Documentation
                ─────────────
                  https://developer.apple.com/documentation/metrickit/mxhangdiagnostic
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
        let document = try makeDocument(rawJSON, technology: "packagedescription", path: "package")
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

                Documentation
                ─────────────
                  https://developer.apple.com/documentation/packagedescription/package
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

    @Test("renders semantic JSON with optional agent navigation", arguments: [OutputAudience.human, .agent])
    func rendersSemanticJSON(audience: OutputAudience) throws {
        // -- Arrange --
        let document = try makeDocument(
            #"{"metadata":{"title":"MXHangDiagnostic","symbolKind":"class"},"unknownField":true}"#)
        let renderer = DefaultTypeDocumentationRenderer(output: .json, audience: audience)

        // -- Act --
        let output = try renderer.render(document)
        let value = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])

        // -- Assert --
        #expect(value["title"] as? String == "MXHangDiagnostic")
        #expect(value["kind"] as? String == "class")
        #expect(value["metadata"] == nil)
        #expect(value["unknownField"] == nil)
        #expect((value["navigation"] != nil) == (audience == .agent))
    }

    @Test("JSON rejects documents without required semantic metadata")
    func rejectsMalformedJSONPage() throws {
        // -- Arrange --
        let rawJSON = #"{"unknownField":true}"#

        // -- Act --
        let decode = { try makeDocument(rawJSON) }

        // -- Assert --
        #expect(throws: DecodingError.self) { try decode() }
    }

    private func makeDocument(
        _ rawJSON: String, technology: String = "metrickit", path: String = "mxhangdiagnostic"
    ) throws -> DocumentationPage {
        try DocumentationPageDecoder().decode(
            Data(rawJSON.utf8),
            destination: .init(technology: technology, path: "/documentation/\(technology)/\(path)"))
    }
}
