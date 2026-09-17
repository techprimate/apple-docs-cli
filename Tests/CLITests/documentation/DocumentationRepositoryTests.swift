import Foundation
import Logging
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Documentation repository")
struct DocumentationRepositoryTests {
    @Test("fetches an exact nested path once without rewriting overload punctuation")
    func fetchesExactPage() async throws {
        // -- Arrange --
        let destination = DocumentationDestination(
            technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic/member.with.dots(_:)",
            fragment: "Overview"
        )
        let expectedURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/metrickit/"
                    + "mxhangdiagnostic/member.with.dots(_:).json"
            ))
        let responseData = DocumentationFixtures.member
        let transport = HTTPTestTransport(responses: [expectedURL: .http(data: responseData)])
        let repository = makeRepository(transport)

        // -- Act --
        let loaded = try await repository.page(at: destination)

        // -- Assert --
        #expect(loaded.page.destination == destination)
        #expect(loaded.page.title == "member(_:)")
        #expect(loaded.responseByteCount == responseData.count)
        #expect(await transport.requestedURLs == [expectedURL])
    }

    @Test("resolves a root display name and retains content without downloading it again")
    func fetchesCanonicalRoot() async throws {
        // -- Arrange --
        let requestedURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/apple%20cryptokit.json"))
        let catalogURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/technologies.json"))
        let canonicalURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/cryptokit.json"))
        let data = Data(#"{"metadata":{"title":"Apple CryptoKit","role":"collection"},"references":{}}"#.utf8)
        let transport = HTTPTestTransport(responses: [
            requestedURL: .http(statusCode: 404, data: Data()),
            catalogURL: .http(data: catalogData), canonicalURL: .http(data: data),
        ])
        let repository = makeRepository(transport)

        // -- Act --
        let loaded = try await repository.root(technology: "Apple CryptoKit")

        // -- Assert --
        #expect(
            loaded.page.destination
                == DocumentationDestination(
                    technology: "cryptokit", path: "/documentation/cryptokit"
                ))
        #expect(loaded.page.title == "Apple CryptoKit")
        #expect(loaded.responseByteCount == data.count)
        #expect(await transport.requestedURLs == [requestedURL, catalogURL, canonicalURL])
    }

    @Test("named input retains dotted-name conversion and canonical technology retry")
    func fetchesNamedType() async throws {
        // -- Arrange --
        let requestedURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/apple%20cryptokit/aes/gcm.json"))
        let catalogURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/technologies.json"))
        let canonicalURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/cryptokit/aes/gcm.json"))
        let data = Data(#"{"metadata":{"title":"GCM","symbolKind":"enum"}}"#.utf8)
        let transport = HTTPTestTransport(responses: [
            requestedURL: .http(statusCode: 404, data: Data()),
            catalogURL: .http(data: catalogData), canonicalURL: .http(data: data),
        ])
        let repository = makeRepository(transport)

        // -- Act --
        let loaded = try await repository.type(named: "AES.GCM", technology: "Apple CryptoKit")

        // -- Assert --
        #expect(
            loaded.page.destination
                == DocumentationDestination(
                    technology: "cryptokit", path: "/documentation/cryptokit/aes/gcm"
                ))
        #expect(loaded.responseByteCount == data.count)
        #expect(await transport.requestedURLs == [requestedURL, catalogURL, canonicalURL])
    }

    @Test("preserves HTTP and non-HTTP validation at the existing transport boundary", arguments: [true, false])
    func validatesResponse(http: Bool) async throws {
        // -- Arrange --
        let destination = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
        let url = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/swift/string.json"))
        let response: HTTPTestTransport.Response =
            http
            ? .http(statusCode: 503, data: DocumentationFixtures.member)
            : .response(
                data: DocumentationFixtures.member,
                response: URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
        let transport = HTTPTestTransport(responses: [url: response])
        let repository = makeRepository(transport)
        let expected: DefaultAppleDocumentationClient<HTTPTestTransport>.Error =
            http
            ? .httpStatus(503) : .invalidResponse

        // -- Act --
        await #expect(throws: expected) { try await repository.page(at: destination) }

        // -- Assert --
        #expect(await transport.requestedURLs == [url])
    }

    private func makeRepository(
        _ transport: HTTPTestTransport
    ) -> DefaultDocumentationRepository {
        DefaultDocumentationRepository(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: DefaultAppleDocumentationClient(
                logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport
            ))
    }

    private var catalogData: Data {
        Data(
            #"""
            {"sections":[{"groups":[{"technologies":[{
              "title":"Apple CryptoKit",
              "destination":{"identifier":"doc://com.apple.documentation/documentation/CryptoKit"}
            }]}]}]}
            """#.utf8)
    }
}
