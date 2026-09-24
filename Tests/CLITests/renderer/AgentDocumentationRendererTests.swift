import Foundation
import Testing

@testable import CLI

@Suite("Agent documentation text")
struct AgentDocumentationRendererTests {
    @Test("renders full normalized Markdown with explicit paths and executable follow-up commands")
    func rendersCompletePage() throws {
        // -- Arrange --
        let destination = DocumentationDestination(
            technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic/member(_:)"
        )
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        let presentation = DocumentationPresenter().page(page, audience: .agent)

        // -- Act --
        let output = AgentDocumentationRenderer().render(presentation)

        // -- Assert --
        #expect(output.contains("# member(\\_:)"))
        #expect(output.contains("Technology: `metrickit`"))
        #expect(output.contains("Path: `/documentation/metrickit/mxhangdiagnostic/member(_:)`"))
        #expect(output.contains("## Summary\n\nRead `value` with [a string]"))
        #expect(output.contains("```swift\nfunc member(_ value: String)\n```"))
        #expect(output.contains("```occ\n- (void)member;\n```"))
        #expect(output.contains("## Availability"))
        #expect(output.contains("macOS: introduced 15.0, deprecated 26.0, obsoleted 27.0, beta, unavailable"))
        #expect(output.contains("## Deprecated\n\nUse the replacement."))
        #expect(output.contains("3. First\n\n   - Nested"))
        #expect(output.contains("> Important\n> Take care."))
        #expect(output.contains("## Relationships\n\n### Conforms To"))
        #expect(output.contains("## Topics\n\n### Children"))
        #expect(output.contains("Text storage."))
        #expect(output.contains("apple-docs types view 'string' --technology 'swift' --agent"))
        #expect(output.contains("## See Also\n\n### Guides"))
        #expect(output.contains("https://example.com/guide"))
        #expect(!output.contains("javascript:"))
    }

    @Test("code fences cannot be closed by embedded backticks and remote controls are inert")
    func rendersUntrustedCode() {
        // -- Arrange --
        let page = DocumentationPage(
            destination: DocumentationDestination(technology: "swift", path: "/documentation/swift/string"),
            title: "String\u{001B}[2J", kind: "struct",
            content: [.codeListing(code: ["```", "[value]", "\u{009B}31m"], syntax: "swift")]
        )
        let presentation = DocumentationPresenter().page(page, audience: .agent)

        // -- Act --
        let output = AgentDocumentationRenderer().render(presentation)

        // -- Assert --
        #expect(output.contains("````swift\n```\n[value]\n31m\n````"))
        #expect(!output.contains("\u{001B}"))
        #expect(!output.contains("\u{009B}"))
    }

    @Test("symbol and technology Markdown retain navigation and discovery fields")
    func rendersDiscovery() {
        // -- Arrange --
        let presenter = DocumentationPresenter()
        let symbols = presenter.symbols(
            [
                DocumentationType(
                    name: "String", kind: "struct", path: "string",
                    url: "https://developer.apple.com/documentation/swift/string")
            ], technology: "Swift", audience: .agent)
        let technologies = presenter.technologies(
            [
                Technology(name: "Swift", identifier: "doc://swift/documentation/Swift")
            ], audience: .agent)

        // -- Act --
        let symbolOutput = AgentDocumentationRenderer().render(symbols, technology: "Swift")
        let technologyOutput = AgentDocumentationRenderer().render(technologies)

        // -- Assert --
        #expect(symbolOutput.contains("Technology: `Swift`"))
        #expect(symbolOutput.contains("Kind: struct"))
        #expect(symbolOutput.contains("Path: `string`"))
        #expect(symbolOutput.contains("apple-docs types view 'string' --technology 'swift' --agent"))
        #expect(technologyOutput.contains("doc://swift/documentation/Swift"))
        #expect(technologyOutput.contains("apple-docs types list --technology 'swift' --agent"))
    }
}
