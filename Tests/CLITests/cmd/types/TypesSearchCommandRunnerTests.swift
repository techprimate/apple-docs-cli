import Foundation
import Testing

@testable import CLI

@Suite("Types search command runner")
struct TypesSearchCommandRunnerTests {
    @Test("searches and renders types for the requested technology")
    func searchesAndRendersTypes() async throws {
        // -- Arrange --
        let types = [
            DocumentationType(
                name: "Button",
                kind: "struct",
                path: "button",
                url: "https://developer.apple.com/documentation/swiftui/button"
            )
        ]
        let runner = TypesSearchCommandRunner(
            client: RequestedTypeSearchClient(types: types),
            renderer: SearchTypesRenderer(expectedTypes: types)
        )

        // -- Act --
        let result = try await runner.run(
            query: "Button", technology: "SwiftUI", mode: .oneShot(audience: .human, format: .text))

        // -- Assert --
        #expect(result.output == "rendered matches")
        #expect(result.matchCount == 1)
        #expect(result.unavailableCollectionCount == 1)
    }

    @Test("empty searches are successful structured results with coverage")
    func rendersEmptySearch() async throws {
        // -- Arrange --
        let runner = TypesSearchCommandRunner(
            client: RequestedTypeSearchClient(types: []),
            renderer: DefaultDocumentationSearchRenderer(output: .json))

        // -- Act --
        let result = try await runner.run(
            query: "Button", technology: "SwiftUI", mode: .oneShot(audience: .human, format: .json))

        // -- Assert --
        let json = try #require(JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [String: Any])
        #expect((json["types"] as? [Any])?.isEmpty == true)
        let coverage = try #require(json["coverage"] as? [String: Any])
        #expect(coverage["isComplete"] as? Bool == false)
        #expect(result.matchCount == 0)
        #expect(result.unavailableCollectionCount == 1)
    }
}

private struct RequestedTypeSearchClient: DocumentationTypeSearchRepository {
    let types: [DocumentationType]

    func searchTypes(query: String, technology: String) async throws -> DocumentationSearchResult {
        guard query == "Button", technology == "SwiftUI" else {
            throw TypesSearchRunnerTestError.unexpectedRequest
        }
        return DocumentationSearchResult(
            technology: "swiftui", types: types,
            unavailableCollections: [
                DocumentationCollectionFailure(path: "/documentation/swiftui/styles", reason: .httpStatus(404))
            ])
    }
}

private struct SearchTypesRenderer: DocumentationSearchRenderer {
    let expectedTypes: [DocumentationType]

    func render(_ result: DocumentationSearchResult) throws -> String {
        guard result.types == expectedTypes else {
            throw TypesSearchRunnerTestError.unexpectedTypes
        }
        return "rendered matches"
    }
}

private enum TypesSearchRunnerTestError: Error {
    case unexpectedRequest
    case unexpectedTypes
}
