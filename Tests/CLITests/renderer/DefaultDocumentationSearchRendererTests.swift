import Foundation
import Testing

@testable import CLI

@Suite("Documentation search rendering")
struct DefaultDocumentationSearchRendererTests {
    @Test("JSON exposes partial coverage even when there are no matches", arguments: [OutputAudience.human, .agent])
    func rendersIncompleteSearch(audience: OutputAudience) throws {
        // -- Arrange --
        let result = DocumentationSearchResult(
            technology: "swiftui", types: [],
            unavailableCollections: [
                .init(path: "/documentation/swiftui/controls", reason: .httpStatus(503)),
                .init(path: "/documentation/swiftui/layout", reason: .decoding),
            ])
        let renderer = DefaultDocumentationSearchRenderer(output: .json, audience: audience)

        // -- Act --
        let output = try renderer.render(result)
        let json = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
        let coverage = try #require(json["coverage"] as? [String: Any])
        let unavailable = try #require(coverage["unavailableCollections"] as? [[String: Any]])

        // -- Assert --
        #expect(json["technology"] as? String == "swiftui")
        #expect((json["types"] as? [Any])?.isEmpty == true)
        #expect(coverage["isComplete"] as? Bool == false)
        #expect(unavailable.count == 2)
        #expect(unavailable[0]["path"] as? String == "/documentation/swiftui/controls")
        #expect(unavailable[0]["kind"] as? String == "http")
        #expect(unavailable[0]["status"] as? Int == 503)
        #expect(unavailable[1]["kind"] as? String == "decoding")
    }

    @Test("complete empty searches retain explicit coverage")
    func rendersCompleteEmptySearch() throws {
        // -- Arrange --
        let result = DocumentationSearchResult(technology: "swift", types: [], unavailableCollections: [])

        // -- Act --
        let output = try DefaultDocumentationSearchRenderer(output: .json).render(result)
        let json = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
        let coverage = try #require(json["coverage"] as? [String: Any])

        // -- Assert --
        #expect(coverage["isComplete"] as? Bool == true)
        #expect((coverage["unavailableCollections"] as? [Any])?.isEmpty == true)
        #expect((json["types"] as? [Any])?.isEmpty == true)
    }
}
