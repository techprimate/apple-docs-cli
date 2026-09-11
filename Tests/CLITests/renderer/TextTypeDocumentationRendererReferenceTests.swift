import Foundation
import Testing

@testable import CLI

@Suite("Text type documentation reference rendering")
struct TextTypeDocumentationRendererReferenceTests {
    @Test("renders the canonical documentation URL")
    func rendersCanonicalURL() throws {
        // -- Arrange --
        let data = Data(
            """
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
              "references": {},
              "variants": [{
                "paths": ["/documentation/metrickit/mxhangdiagnostic"],
                "traits": [{"interfaceLanguage": "swift"}]
              }]
            }
            """.utf8
        )
        let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(
            output.hasSuffix(
                "https://developer.apple.com/documentation/metrickit/mxhangdiagnostic"
            )
        )
    }

    @Test("renders inline references and follow-up links in documentation sections")
    func rendersInlineReferencesAndLinks() throws {
        // -- Arrange --
        let data = Data(
            """
            {
              "abstract": [],
              "metadata": {
                "modules": [{"name": "SwiftUI"}],
                "platforms": [],
                "roleHeading": "Structure",
                "symbolKind": "struct",
                "title": "Button"
              },
              "primaryContentSections": [],
              "references": {
                "doc://button-init": {
                  "abstract": [
                    {"text": "Creates a button that performs an ", "type": "text"},
                    {"code": "AppIntent", "type": "codeVoice"},
                    {"text": ".", "type": "text"}
                  ],
                  "kind": "symbol",
                  "role": "symbol",
                  "title": "init(intent:label:)",
                  "type": "topic",
                  "url": "/documentation/swiftui/button/init(intent:label:)"
                }
              },
              "topicSections": [{
                "identifiers": ["doc://button-init"],
                "title": "Creating a button"
              }]
            }
            """.utf8
        )
        let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(output.contains("  • init(intent:label:)\n    Creates a button that performs an `AppIntent`."))
        #expect(
            output.contains(
                "https://developer.apple.com/documentation/swiftui/button/init(intent:label:)"
            )
        )
    }
}
