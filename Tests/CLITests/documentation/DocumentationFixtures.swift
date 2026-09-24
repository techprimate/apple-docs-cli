import Foundation

enum DocumentationFixtures {
    static let member = Data(
        #"""
        {
          "kind": "symbol",
          "metadata": {
            "title": "member(_:)", "role": "symbol", "symbolKind": "method", "roleHeading": "Method",
            "modules": [{"name": "MetricKit"}],
            "platforms": [{"name": "macOS", "introducedAt": "15.0", "deprecatedAt": "26.0",
              "obsoletedAt": "27.0", "beta": true, "unavailable": true}]
          },
          "abstract": [
            {"type": "text", "text": "Read "}, {"type": "codeVoice", "code": "value"},
            {"type": "text", "text": " with "},
            {"type": "reference", "identifier": "doc://string", "overridingTitle": "a string"},
            {"type": "emphasis", "inlineContent": [{"text": "."}]}
          ],
          "deprecationSummary": [{"type": "paragraph", "inlineContent": [{"text": "Use the replacement."}]}],
          "primaryContentSections": [
            {"kind": "declarations", "declarations": [
              {"languages": ["swift"], "tokens": [{"text": "func "}, {"text": "member(_ value: String)"}]},
              {"languages": ["occ"], "tokens": [{"text": "- (void)member;"}]}
            ]},
            {"kind": "content", "content": [
              {"type": "heading", "text": "Overview"},
              {"type": "paragraph", "inlineContent": [
                {"type": "reference", "identifier": "https://example.com/guide"},
                {"type": "reference", "identifier": "doc://missing", "overridingTitle": "Missing"},
                {"type": "reference", "identifier": "doc://unsafe"}
              ]},
              {"type": "codeListing", "syntax": "swift", "code": ["member(\"value\")", ""]},
              {"type": "orderedList", "startIndex": 3, "items": [{"content": [
                {"type": "paragraph", "inlineContent": [{"text": "First"}]},
                {"type": "unorderedList", "items": [{"content": [
                  {"type": "paragraph", "inlineContent": [{"text": "Nested"}]}
                ]}]}
              ]}]},
              {"type": "aside", "style": "warning", "name": "Important", "content": [
                {"type": "paragraph", "inlineContent": [{"text": "Take care."}]}
              ]}
            ]}
          ],
          "relationshipsSections": [{"title": "Conforms To", "identifiers": ["doc://string"]}],
          "topicSections": [{"title": "Children", "identifiers": ["doc://missing", "doc://string"]}],
          "seeAlsoSections": [{"title": "Guides", "identifiers": ["https://example.com/guide"]}],
          "references": {
            "doc://string": {"title": "String", "kind": "symbol", "role": "symbol",
              "url": "/documentation/swift/string", "abstract": [{"text": "Text storage."}]},
            "https://example.com/guide": {"title": "Guide", "kind": "link", "url": "https://example.com/guide"},
            "doc://unsafe": {"title": "Unsafe", "url": "javascript:alert(1)"}
          }
        }
        """#.utf8)
}
