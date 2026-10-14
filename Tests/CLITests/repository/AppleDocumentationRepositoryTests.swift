import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Semantic documentation repository")
struct AppleDocumentationRepositoryTests {
    @Test("loads a semantic page while preserving exact destinations and response size")
    func loadsExactPage() async throws {
        // -- Arrange --
        let url = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swift/String/init(_:)-1.json"))
        let data = Data(#"{"metadata":{"title":"init(_:)","symbolKind":"init"}}"#.utf8)
        let transport = HTTPTestTransport(responses: [url: .http(data: data)])
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let repository = DefaultAppleDocumentationRepository(
            logger: logger, dependencies: DefaultAppleDocumentationClient(logger: logger, dependencies: transport))
        let destination = DocumentationDestination(
            technology: "swift", path: "/documentation/swift/String/init(_:)-1", fragment: "discussion")

        // -- Act --
        let result = try await repository.fetchPage(at: destination)

        // -- Assert --
        #expect(result.page.title == "init(_:)")
        #expect(result.page.destination == destination)
        #expect(result.responseByteCount == data.count)
        #expect(await transport.requestedURLs == [url])
    }

    @Test("rejects malformed semantic pages before rendering")
    func rejectsMalformedPage() async throws {
        // -- Arrange --
        let url = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swift/string.json"))
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let repository = DefaultAppleDocumentationRepository(
            logger: logger,
            dependencies: DefaultAppleDocumentationClient(
                logger: logger, dependencies: HTTPTestTransport(responses: [url: .http(data: Data("{}".utf8))])))

        // -- Act --
        let load = { try await repository.fetchPage(named: "String", technology: "Swift") }

        // -- Assert --
        await #expect(throws: DecodingError.self) { try await load() }
    }
}
