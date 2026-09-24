import Foundation
import Testing

@testable import CLI

@Suite("Structured documentation rendering")
struct StructuredDocumentationRendererTests {
    @Test("page JSON has stable semantic fields rather than raw DocC or rendered text")
    func rendersPageContract() throws {
        // -- Arrange --
        let destination = DocumentationDestination(
            technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic/member(_:)"
        )
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        let presentation = DocumentationPresenter().page(page, audience: .human)

        // -- Act --
        let output = try StructuredDocumentationRenderer().render(presentation)
        let value = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])

        // -- Assert --
        #expect(
            Set(value.keys)
                == Set([
                    "title", "kind", "technology", "path", "url", "modules", "abstract", "deprecation", "declarations",
                    "availability", "content", "relationships", "topics", "seeAlso",
                ]))
        #expect(value["title"] as? String == "member(_:)")
        #expect(value["technology"] as? String == "metrickit")
        #expect(value["path"] as? String == "/documentation/metrickit/mxhangdiagnostic/member(_:)")
        #expect(value["metadata"] == nil)
        let abstract = try #require(value["abstract"] as? [[String: Any]])
        #expect(abstract[1]["type"] as? String == "code")
        #expect(abstract[1]["text"] as? String == "value")
        #expect(abstract[3]["type"] as? String == "link")
        #expect(abstract[3]["text"] as? String == "a string")
        let target = try #require(abstract[3]["target"] as? [String: Any])
        #expect(target["type"] as? String == "documentation")
        #expect(target["path"] as? String == "/documentation/swift/string")
        let content = try #require(value["content"] as? [[String: Any]])
        #expect(
            content.map { $0["type"] as? String } == ["heading", "paragraph", "codeListing", "orderedList", "aside"])
        #expect(content[2]["code"] as? [String] == ["member(\"value\")", ""])
        #expect(content[2]["syntax"] as? String == "swift")
        #expect(content[3]["startIndex"] as? Int == 3)
        #expect(content[4]["style"] as? String == "warning")
        #expect(content[4]["name"] as? String == "Important")
        #expect(content[0]["items"] == nil)
        #expect(!output.contains("\\/"))
        #expect(!output.contains("\u{001B}"))
    }

    @Test("agent JSON adds navigation on pages and references without dropping content")
    func rendersAgentNavigation() throws {
        // -- Arrange --
        let destination = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        let presentation = DocumentationPresenter().page(page, audience: .agent)

        // -- Act --
        let output = try StructuredDocumentationRenderer().render(presentation)
        let value = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])

        // -- Assert --
        let navigation = try #require(value["navigation"] as? [String: Any])
        #expect(navigation["command"] as? String == "apple-docs types view 'string' --technology 'swift' --agent")
        let topics = try #require(value["topics"] as? [[String: Any]])
        let references = try #require(topics[0]["references"] as? [[String: Any]])
        #expect(references[0]["navigation"] != nil)
        #expect((value["declarations"] as? [Any])?.count == 2)
        #expect((value["content"] as? [Any])?.count == 5)
    }

    @Test("discovery JSON remains a top-level array with existing result fields")
    func rendersDiscoveryArrays() throws {
        // -- Arrange --
        let symbols = [
            DocumentationType(
                name: "String", kind: "struct", path: "string",
                url: "https://developer.apple.com/documentation/swift/string")
        ]
        let technologies = [Technology(name: "Swift", identifier: "doc://swift/documentation/Swift")]
        let presenter = DocumentationPresenter()
        let renderer = StructuredDocumentationRenderer()

        // -- Act --
        let symbolText = try renderer.render(presenter.symbols(symbols, technology: "Swift", audience: .human))
        let technologyText = try renderer.render(presenter.technologies(technologies, audience: .human))
        let symbolValues = try #require(JSONSerialization.jsonObject(with: Data(symbolText.utf8)) as? [[String: Any]])
        let technologyValues = try #require(
            JSONSerialization.jsonObject(with: Data(technologyText.utf8)) as? [[String: Any]])

        // -- Assert --
        #expect(Set(symbolValues[0].keys) == Set(["name", "kind", "path", "url"]))
        #expect(Set(technologyValues[0].keys) == Set(["name", "identifier"]))
        #expect(symbolValues[0]["name"] as? String == "String")
        #expect(technologyValues[0]["identifier"] as? String == "doc://swift/documentation/Swift")
    }
}
