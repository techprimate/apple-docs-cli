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
        let result = try await runner.run(query: "Button", technology: "SwiftUI")

        // -- Assert --
        #expect(result.output == "rendered matches")
        #expect(result.matchCount == 1)
    }
}

private struct RequestedTypeSearchClient: DocumentationTypeSearchClient {
    let types: [DocumentationType]

    func searchTypes(query: String, technology: String) async throws -> [DocumentationType] {
        guard query == "Button", technology == "SwiftUI" else {
            throw TypesSearchRunnerTestError.unexpectedRequest
        }
        return types
    }
}

private struct SearchTypesRenderer: DocumentationTypeListRenderer {
    let expectedTypes: [DocumentationType]

    func render(_ types: [DocumentationType]) throws -> String {
        guard types == expectedTypes else {
            throw TypesSearchRunnerTestError.unexpectedTypes
        }
        return "rendered matches"
    }
}

private enum TypesSearchRunnerTestError: Error {
    case unexpectedRequest
    case unexpectedTypes
}
