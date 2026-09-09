import Foundation
import Testing

@testable import CLI

@Suite("Apple documentation type catalog client")
struct AppleDocumentationClientTypeListTests {
    @Test("lists direct symbols from a technology root document")
    func listsTechnologyRootSymbols() async throws {
        // -- Arrange --
        let rootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftdata.json")
        )
        let client = DefaultAppleDocumentationClient(
            dependencies: TypeCatalogTestTransport(
                responses: [rootURL: .init(statusCode: 200, data: swiftDataRootData)]
            )
        )

        // -- Act --
        let types = try await client.fetchTypes(technology: "SwiftData")

        // -- Assert --
        #expect(types.map(\.name) == ["Index(_:)", "Model()"])
        #expect(types.map(\.kind) == ["macro", "macro"])
        #expect(types.map(\.path) == ["index(_:)-74ia2", "model()"])
        #expect(
            types.map(\.url)
                == [
                    "https://developer.apple.com/documentation/swiftdata/index(_:)-74ia2",
                    "https://developer.apple.com/documentation/swiftdata/model()",
                ]
        )
    }

    @Test("maps a missing resolved root to unsupported technology guidance")
    func mapsMissingResolvedRoot() async throws {
        // -- Arrange --
        let requestedRootURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/apple%20cryptokit.json"
            )
        )
        let technologiesURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/technologies.json"
            )
        )
        let resolvedRootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/cryptokit.json")
        )
        let client = DefaultAppleDocumentationClient(
            dependencies: TypeCatalogTestTransport(
                responses: [
                    requestedRootURL: .init(statusCode: 404, data: Data()),
                    technologiesURL: .init(statusCode: 200, data: cryptoKitCatalogData),
                    resolvedRootURL: .init(statusCode: 404, data: Data()),
                ]
            )
        )

        // -- Act --
        do {
            _ = try await client.fetchTypes(technology: "Apple CryptoKit")
            Issue.record("Expected the request to fail")
        } catch {
            // -- Assert --
            #expect(
                error.localizedDescription == """
                    Type retrieval is unavailable for Apple CryptoKit.

                    Continue in the technology documentation:
                      https://developer.apple.com/documentation/cryptokit
                    """
            )
        }
    }

    @Test("links to unsupported external technology documentation")
    func linksUnsupportedTechnology() async throws {
        // -- Arrange --
        let rootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/carekit.json")
        )
        let technologiesURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/technologies.json")
        )
        let client = DefaultAppleDocumentationClient(
            dependencies: TypeCatalogTestTransport(
                responses: [
                    rootURL: .init(statusCode: 404, data: Data()),
                    technologiesURL: .init(statusCode: 200, data: externalTechnologyCatalogData),
                ]
            )
        )

        // -- Act --
        do {
            _ = try await client.fetchTypes(technology: "CareKit")
            Issue.record("Expected the request to fail")
        } catch {
            // -- Assert --
            #expect(
                error.localizedDescription == """
                    Type retrieval is unavailable for CareKit.

                    Continue in the technology documentation:
                      https://carekit-apple.github.io/CareKit/documentation/carekit
                    """
            )
        }
    }
}

private let swiftDataRootData = Data(
    """
    {
      "references": {
        "doc://module": {
          "fragments": [{"kind": "identifier", "text": "SwiftData"}],
          "kind": "symbol",
          "role": "collection",
          "title": "SwiftData",
          "url": "/documentation/swiftdata"
        },
        "doc://article": {
          "kind": "article",
          "role": "article",
          "title": "Using SwiftData",
          "url": "/documentation/swiftdata/using-swiftdata"
        },
        "doc://model": {
          "fragments": [{"kind": "keyword", "text": "macro"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "Model()",
          "url": "/documentation/swiftdata/model()"
        },
        "doc://index": {
          "fragments": [{"kind": "keyword", "text": "macro"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "Index(_:)",
          "url": "/documentation/swiftdata/index(_:)-74ia2"
        }
      }
    }
    """.utf8
)

private let cryptoKitCatalogData = Data(
    """
    {
      "sections": [{
        "groups": [{
          "technologies": [{
            "destination": {
              "identifier": "doc://com.apple.documentation/documentation/CryptoKit"
            },
            "title": "Apple CryptoKit"
          }]
        }]
      }]
    }
    """.utf8
)

private let externalTechnologyCatalogData = Data(
    """
    {
      "sections": [{
        "groups": [{
          "technologies": [{
            "destination": {
              "identifier": "https://carekit-apple.github.io/CareKit/documentation/carekit"
            },
            "title": "CareKit"
          }]
        }]
      }]
    }
    """.utf8
)

private struct TypeCatalogTestTransport: HTTPDataTransport {
    struct Response: Sendable {
        let statusCode: Int
        let data: Data
    }

    let responses: [URL: Response]

    func data(from url: URL) async throws -> (Data, URLResponse) {
        guard let result = responses[url] else {
            throw TypeCatalogTestError.unexpectedURL(url)
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: result.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (result.data, response)
    }
}

private enum TypeCatalogTestError: Error {
    case unexpectedURL(URL)
}
