import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Documentation page requests")
struct AppleDocumentationClientPageTests {
    @Test("preserves exact path spelling and response bytes without fetching fragments")
    func fetchesExactPage() async throws {
        // -- Arrange --
        let destination = DocumentationDestination(
            technology: "swift", path: "/documentation/swift/Member.with.dots(_:)", fragment: "Overview")
        let url = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swift/Member.with.dots(_:).json"))
        let data = Data("{ \"newUpstreamField\": true }\n".utf8)
        let transport = HTTPTestTransport(responses: [url: .http(data: data)])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport)

        // -- Act --
        let document = try await client.fetchDocument(at: destination)

        // -- Assert --
        #expect(document.destination == destination)
        #expect(document.data == data)
        #expect(await transport.requestedURLs == [url])
    }

    @Test("canonical root discovery retains bytes without downloading the document twice")
    func retainsCanonicalRoot() async throws {
        // -- Arrange --
        let requestedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/apple%20cryptokit.json"))
        let catalogURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/technologies.json"))
        let canonicalURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/cryptokit.json"))
        let catalog = Data(
            #"""
            {"sections":[{"groups":[{"technologies":[{
              "title":"Apple CryptoKit",
              "destination":{"identifier":"doc://com.apple.documentation/documentation/CryptoKit"}
            }]}]}]}
            """#.utf8)
        let data = Data(#"{"metadata":{"title":"Apple CryptoKit","role":"collection"},"references":{}}"#.utf8)
        let transport = HTTPTestTransport(responses: [
            requestedURL: .http(statusCode: 404, data: Data()), catalogURL: .http(data: catalog),
            canonicalURL: .http(data: data),
        ])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport)

        // -- Act --
        let document = try await client.fetchRootDocument(technology: "Apple CryptoKit")

        // -- Assert --
        #expect(
            document.destination == DocumentationDestination(technology: "cryptokit", path: "/documentation/cryptokit"))
        #expect(document.data == data)
        #expect(await transport.requestedURLs == [requestedURL, catalogURL, canonicalURL])
    }
}
