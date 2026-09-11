import Foundation
import Testing

@testable import CLI

@Suite("Text type documentation content rendering")
struct TextTypeDocumentationRendererContentTests {
    @Test("renders overview prose, inline symbols, and indented code examples")
    func rendersOverview() throws {
        // -- Arrange --
        let page = try makePage(
            content: #"""
                {"type": "heading", "level": 2, "text": "Overview"},
                {"type": "paragraph", "inlineContent": [
                  {"type": "text", "text": "Implement "},
                  {"type": "reference", "identifier": "doc://body"},
                  {"type": "text", "text": " using "},
                  {"type": "codeVoice", "code": "Text"},
                  {"type": "text", "text": "."}
                ]},
                {"type": "codeListing", "syntax": "swift", "code": [
                  "var body: some View {", "    Text(\"Hello\")", "", "}"
                ]}
                """#
        )

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(output.contains("Overview\n────────\n\n  Implement body using `Text`."))
        #expect(
            output.contains(
                """
                  ╭─ Swift ───────────────╮
                  │ var body: some View { │
                  │     Text("Hello")     │
                  │                       │
                  │ }                     │
                  ╰───────────────────────╯
                """
            )
        )
    }

    @Test("wraps prose to 80 columns with consistent indentation")
    func wrapsProse() throws {
        // -- Arrange --
        let page = try makePage(
            content: """
                {"type": "paragraph", "inlineContent": [
                  {"text": "This paragraph contains enough words to extend beyond the usual terminal width. "},
                  {"text": "The next sentence should continue on an indented line."}
                ]}
                """
        )

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(
            output.contains(
                """
                  This paragraph contains enough words to extend beyond the usual terminal
                  width. The next sentence should continue on an indented line.
                """
            )
        )
    }

    @Test("renders nested lists and note callouts")
    func rendersListsAndNotes() throws {
        // -- Arrange --
        let page = try makePage(
            content: """
                {"type": "orderedList", "startIndex": 3, "items": [
                  {"content": [
                    {"type": "paragraph", "inlineContent": [{"text": "Create a view."}]},
                    {"type": "unorderedList", "items": [{"content": [
                      {"type": "paragraph", "inlineContent": [{"text": "Add a body."}]}
                    ]}]}
                  ]},
                  {"content": [{"type": "paragraph", "inlineContent": [{"text": "Preview it."}]}]}
                ]},
                {"type": "aside", "style": "note", "name": "Note", "content": [
                  {"type": "paragraph", "inlineContent": [{"text": "Keep the body lightweight."}]}
                ]}
                """
        )

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(output.contains("  3. Create a view.\n\n     • Add a body.\n  4. Preview it."))
        #expect(output.contains("  Note\n  │ Keep the body lightweight."))
    }

    @Test("preserves mixed inline content in the summary")
    func rendersMixedSummary() throws {
        // -- Arrange --
        let page = try makePage(
            abstract: """
                {"text": "A "}, {"type": "codeVoice", "code": "View"},
                {"text": " with "}, {"type": "reference", "identifier": "doc://body"},
                {"text": " and "}, {"type": "emphasis", "inlineContent": [{"text": "style"}]},
                {"text": "."}
                """
        )

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(output.contains("  A `View` with body and style."))
    }

    @Test("omits empty content and unresolved reference groups")
    func omitsEmptySections() throws {
        // -- Arrange --
        let page = try makePage(
            content: """
                {"type": "futureBlock", "items": [{"title": "An unsupported item"}]},
                {"type": "paragraph", "inlineContent": []}
                """)

        // -- Act --
        let output = TextTypeDocumentationRenderer().render(page)

        // -- Assert --
        #expect(output == "View\n━━━━\nProtocol · SwiftUI")
    }

    @Test(
        "rejects recognized blocks missing required content",
        arguments: [
            #"{"type": "paragraph"}"#,
            #"{"type": "heading"}"#,
            #"{"type": "codeListing", "syntax": "swift"}"#,
            #"{"type": "unorderedList", "items": [{}]}"#,
            #"{"type": "orderedList", "items": [{}]}"#,
            #"{"type": "aside", "style": "note"}"#,
        ]
    )
    func rejectsMalformedKnownBlocks(block: String) {
        // -- Arrange --
        let data = Data(block.utf8)

        // -- Act --
        let decode = { try JSONDecoder().decode(DocumentationBlockDTO.self, from: data) }

        // -- Assert --
        #expect(throws: DecodingError.self) { try decode() }
    }

    private func makePage(abstract: String = "", content: String = "") throws -> TypeDocumentationPageDTO {
        let data = Data(
            """
            {
              "abstract": [\(abstract)],
              "metadata": {
                "modules": [{"name": "SwiftUI"}], "platforms": [],
                "roleHeading": "Protocol", "symbolKind": "protocol", "title": "View"
              },
              "primaryContentSections": [{"kind": "content", "content": [\(content)]}],
              "references": {"doc://body": {"title": "body", "url": "/documentation/swiftui/view/body"}},
              "topicSections": [{"title": "Missing", "identifiers": ["doc://missing"]}]
            }
            """.utf8
        )
        return try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)
    }
}
