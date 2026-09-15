import Foundation
import Logging
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Apple documentation root lookup")
struct AppleDocumentationClientRootTests {
    @Test("maps a missing canonical root to unsupported technology guidance", arguments: [false, true])
    func mapsMissingCanonicalRoot(search: Bool) async throws {
        // -- Arrange --
        let requestedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/apple%20cryptokit.json")
        )
        let catalogURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/technologies.json")
        )
        let canonicalURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/cryptokit.json")
        )
        let transport = RootTestTransport(responses: [
            requestedURL: .init(statusCode: 404, data: Data()),
            catalogURL: .init(statusCode: 200, data: cryptoKitCatalogData),
            canonicalURL: .init(statusCode: 404, data: Data()),
        ])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport
        )

        // -- Act --
        await #expect(
            throws: DefaultAppleDocumentationClient<RootTestTransport>.Error.unsupportedTechnology(
                name: "Apple CryptoKit", url: "https://developer.apple.com/documentation/cryptokit"
            )
        ) {
            if search {
                _ = try await client.searchTypes(query: "AES", technology: "Apple CryptoKit")
            } else {
                _ = try await client.fetchTypes(technology: "Apple CryptoKit")
            }
        }

        // -- Assert --
        #expect(await transport.requestedURLs == [requestedURL, catalogURL, canonicalURL])
    }

    @Test("does not retry an identical case-insensitive root", arguments: [false, true])
    func skipsIdenticalRootRetry(search: Bool) async throws {
        // -- Arrange --
        let rootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/cryptokit.json")
        )
        let catalogURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/technologies.json")
        )
        let transport = RootTestTransport(responses: [
            rootURL: .init(statusCode: 404, data: Data()),
            catalogURL: .init(statusCode: 200, data: cryptoKitCatalogData),
        ])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport
        )

        // -- Act --
        await #expect(
            throws: DefaultAppleDocumentationClient<RootTestTransport>.Error.unsupportedTechnology(
                name: "Apple CryptoKit", url: "https://developer.apple.com/documentation/cryptokit"
            )
        ) {
            if search {
                _ = try await client.searchTypes(query: "AES", technology: "CRYPTOKIT")
            } else {
                _ = try await client.fetchTypes(technology: "CRYPTOKIT")
            }
        }

        // -- Assert --
        #expect(await transport.requestedURLs == [rootURL, catalogURL])
    }

    @Test("returns symbols scoped to the canonical technology", arguments: [false, true])
    func resolvesCanonicalRoot(search: Bool) async throws {
        // -- Arrange --
        let requestedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/apple%20cryptokit.json")
        )
        let catalogURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/technologies.json")
        )
        let canonicalURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/cryptokit.json")
        )
        let rootData = Data(
            """
            {"references":{"aes":{
              "kind":"symbol", "role":"symbol", "title":"AES", "url":"/documentation/cryptokit/aes"
            }}}
            """.utf8
        )
        let transport = RootTestTransport(responses: [
            requestedURL: .init(statusCode: 404, data: Data()),
            catalogURL: .init(statusCode: 200, data: cryptoKitCatalogData),
            canonicalURL: .init(statusCode: 200, data: rootData),
        ])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport
        )

        // -- Act --
        let types =
            try await search
            ? client.searchTypes(query: "AES", technology: "Apple CryptoKit")
            : client.fetchTypes(technology: "Apple CryptoKit")

        // -- Assert --
        #expect(types.map(\.name) == ["AES"])
        #expect(types.map(\.path) == ["aes"])
        #expect(await transport.requestedURLs == [requestedURL, catalogURL, canonicalURL])
    }

    @Test("propagates non-404 root failures without catalog lookup", arguments: [false, true], [429, 500])
    func propagatesRootHTTPFailures(search: Bool, status: Int) async throws {
        // -- Arrange --
        let rootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/cryptokit.json")
        )
        let transport = RootTestTransport(responses: [rootURL: .init(statusCode: status, data: Data())])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport
        )

        // -- Act --
        await #expect(throws: DefaultAppleDocumentationClient<RootTestTransport>.Error.httpStatus(status)) {
            if search {
                _ = try await client.searchTypes(query: "AES", technology: "CryptoKit")
            } else {
                _ = try await client.fetchTypes(technology: "CryptoKit")
            }
        }

        // -- Assert --
        #expect(await transport.requestedURLs == [rootURL])
    }
}

private let cryptoKitCatalogData = Data(
    """
    {"sections":[{"groups":[{"technologies":[{
      "title":"Apple CryptoKit",
      "destination":{"identifier":"doc://com.apple.documentation/documentation/CryptoKit"}
    }]}]}]}
    """.utf8
)

private actor RootTestTransport: HTTPDataTransport {
    struct Response: Sendable {
        let statusCode: Int
        let data: Data
    }

    let responses: [URL: Response]
    private(set) var requestedURLs: [URL] = []

    init(responses: [URL: Response]) {
        self.responses = responses
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        requestedURLs.append(url)
        let result = try #require(responses[url], "Unexpected request: \(url)")
        let response = try #require(
            HTTPURLResponse(
                url: url, statusCode: result.statusCode, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        )
        return (result.data, response)
    }
}
