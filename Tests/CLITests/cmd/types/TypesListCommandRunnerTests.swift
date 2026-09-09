import Testing

@testable import CLI

@Suite("Types list command runner")
struct TypesListCommandRunnerTests {
    @Test("fetches and renders direct types for the requested technology")
    func fetchesAndRendersTypes() async throws {
        // -- Arrange --
        let types = [
            DocumentationType(
                name: "Model()",
                kind: "macro",
                path: "model()",
                url: "https://developer.apple.com/documentation/swiftdata/model()"
            )
        ]
        let runner = TypesListCommandRunner(
            client: RequestedTypesClient(types: types),
            renderer: RequestedTypesRenderer(expectedTypes: types)
        )

        // -- Act --
        let result = try await runner.run(technology: "SwiftData")

        // -- Assert --
        #expect(result.output == "rendered types")
        #expect(result.typeCount == 1)
    }
}

private struct RequestedTypesClient: DocumentationTypeCatalogClient {
    let types: [DocumentationType]

    func fetchTypes(technology: String) async throws -> [DocumentationType] {
        guard technology == "SwiftData" else {
            throw TypesListRunnerTestError.unexpectedTechnology
        }
        return types
    }
}

private struct RequestedTypesRenderer: DocumentationTypeListRenderer {
    let expectedTypes: [DocumentationType]

    func render(_ types: [DocumentationType]) throws -> String {
        guard types == expectedTypes else {
            throw TypesListRunnerTestError.unexpectedTypes
        }
        return "rendered types"
    }
}

private enum TypesListRunnerTestError: Error {
    case unexpectedTechnology
    case unexpectedTypes
}
