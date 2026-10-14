import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Documentation search failure classification")
struct DocumentationSearchFailureTests {
    @Test("retains typed HTTP collection failures", arguments: [404, 429, 503])
    func retainsHTTPFailures(status: Int) async throws {
        // -- Arrange --
        let rootURL = try #require(URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftui.json"))
        let collectionURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftui/controls.json"))
        let repository = makeDocumentationRepository(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [
                rootURL: .http(data: rootSearchPage), collectionURL: .http(statusCode: status, data: Data()),
            ]))

        // -- Act --
        let result = try await repository.searchTypes(query: "Button", technology: "SwiftUI")

        // -- Assert --
        #expect(result.technology == "swiftui")
        #expect(
            result.unavailableCollections == [
                DocumentationCollectionFailure(path: "/documentation/swiftui/controls", reason: .httpStatus(status))
            ])
        #expect(!result.isComplete)
    }

    @Test("propagates unexpected collection errors instead of misreporting incomplete coverage")
    func propagatesUnexpectedFailures() async throws {
        // -- Arrange --
        let rootURL = try #require(URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftui.json"))
        let collectionURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftui/controls.json"))
        let repository = makeDocumentationRepository(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [
                rootURL: .http(data: rootSearchPage), collectionURL: .failure(UnexpectedCollectionFailure()),
            ]))

        // -- Act --
        let search = { try await repository.searchTypes(query: "Button", technology: "SwiftUI") }

        // -- Assert --
        await #expect(throws: UnexpectedCollectionFailure.self) { try await search() }
    }

}

private struct UnexpectedCollectionFailure: Error {}

private let rootSearchPage = Data(
    #"""
    {"references":{"controls":{"role":"collectionGroup","url":"/documentation/swiftui/controls"}}}
    """#.utf8)
