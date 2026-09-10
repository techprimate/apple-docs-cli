import Foundation
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Apple documentation type search client")
struct AppleDocumentationClientSearchTests {
    @Test("searches symbols across nested collection groups")
    func searchesCollectionGroups() async throws {
        // -- Arrange --
        let rootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftui.json")
        )
        let controlsURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/swiftui/controls.json"
            )
        )
        let stylesURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/swiftui/styles.json"
            )
        )
        let client = DefaultAppleDocumentationClient(
            dependencies: SearchTestTransport(
                responses: [
                    rootURL: rootSearchPage,
                    controlsURL: controlsSearchPage,
                    stylesURL: stylesSearchPage,
                ]
            )
        )

        // -- Act --
        let types = try await client.searchTypes(query: "button", technology: "SwiftUI")

        // -- Assert --
        #expect(types.map(\.name) == ["Button", "ButtonStyle"])
        #expect(types.map(\.path) == ["button", "buttonstyle"])
    }

    @Test("deduplicates root symbols with the same path")
    func deduplicatesRootSymbols() async throws {
        // -- Arrange --
        let rootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftui.json")
        )
        let client = DefaultAppleDocumentationClient(
            dependencies: SearchTestTransport(
                responses: [rootURL: duplicateRootSearchPage]
            )
        )

        // -- Act --
        let types = try await client.searchTypes(query: "button", technology: "SwiftUI")

        // -- Assert --
        #expect(types.map(\.name) == ["Button"])
        #expect(types.map(\.path) == ["button"])
    }

    @Test("continues searching when a collection group is unavailable")
    func skipsUnavailableCollectionGroup() async throws {
        // -- Arrange --
        let rootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftui.json")
        )
        let controlsURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/swiftui/controls.json"
            )
        )
        let stylesURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/swiftui/styles.json"
            )
        )
        let client = DefaultAppleDocumentationClient(
            dependencies: SearchFallbackTransport(
                responses: [
                    rootURL: .init(statusCode: 200, data: partialFailureRootSearchPage),
                    controlsURL: .init(statusCode: 404, data: Data()),
                    stylesURL: .init(statusCode: 200, data: stylesSearchPage),
                ]
            )
        )

        // -- Act --
        let types = try await client.searchTypes(query: "buttonstyle", technology: "SwiftUI")

        // -- Assert --
        #expect(types.map(\.name) == ["ButtonStyle"])
        #expect(types.map(\.path) == ["buttonstyle"])
    }

    @Test("maps technology display names to DocC slugs")
    func mapsTechnologyDisplayName() async throws {
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
            dependencies: SearchFallbackTransport(
                responses: [
                    requestedRootURL: .init(statusCode: 404, data: Data()),
                    technologiesURL: .init(statusCode: 200, data: cryptoKitCatalogData),
                    resolvedRootURL: .init(statusCode: 200, data: cryptoKitRootData),
                ]
            )
        )

        // -- Act --
        let types = try await client.searchTypes(query: "AES", technology: "Apple CryptoKit")

        // -- Assert --
        #expect(types.map(\.name) == ["AES"])
        #expect(types.map(\.path) == ["aes"])
    }

    @Test("maps an empty search to discovery guidance")
    func mapsEmptySearchToDiscoveryGuidance() async throws {
        // -- Arrange --
        let rootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftui.json")
        )
        let controlsURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/swiftui/controls.json"
            )
        )
        let stylesURL = try #require(
            URL(
                string:
                    "https://developer.apple.com/tutorials/data/documentation/swiftui/styles.json"
            )
        )
        let client = DefaultAppleDocumentationClient(
            dependencies: SearchTestTransport(
                responses: [
                    rootURL: rootSearchPage,
                    controlsURL: controlsSearchPage,
                    stylesURL: stylesSearchPage,
                ]
            )
        )

        // -- Act --
        do {
            _ = try await client.searchTypes(query: "Picker", technology: "SwiftUI")
            Issue.record("Expected the search to fail")
        } catch {
            // -- Assert --
            #expect(
                error.localizedDescription == """
                    No types matching 'Picker' found in SwiftUI.

                    Browse available types:
                      apple-docs types list --technology "SwiftUI"
                      https://developer.apple.com/documentation/swiftui
                    """
            )
        }
    }
}

private let rootSearchPage = Data(
    """
    {
      "references": {
        "doc://view": {
          "fragments": [{"kind": "keyword", "text": "protocol"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "View",
          "url": "/documentation/swiftui/view"
        },
        "doc://controls": {
          "kind": "article",
          "role": "collectionGroup",
          "title": "Controls",
          "url": "/documentation/swiftui/controls"
        },
        "doc://other-framework": {
          "kind": "article",
          "role": "collectionGroup",
          "title": "UIKit controls",
          "url": "/documentation/uikit/controls"
        }
      }
    }
    """.utf8
)

private let duplicateRootSearchPage = Data(
    """
    {
      "references": {
        "doc://button": {
          "fragments": [{"kind": "keyword", "text": "struct"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "Button",
          "url": "/documentation/swiftui/button"
        },
        "doc://button-duplicate": {
          "fragments": [{"kind": "keyword", "text": "struct"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "Button",
          "url": "/documentation/swiftui/button"
        }
      }
    }
    """.utf8
)

private let partialFailureRootSearchPage = Data(
    """
    {
      "references": {
        "doc://controls": {
          "kind": "article",
          "role": "collectionGroup",
          "title": "Controls",
          "url": "/documentation/swiftui/controls"
        },
        "doc://styles": {
          "kind": "article",
          "role": "collectionGroup",
          "title": "Styles",
          "url": "/documentation/swiftui/styles"
        }
      }
    }
    """.utf8
)

private let controlsSearchPage = Data(
    """
    {
      "references": {
        "doc://button": {
          "fragments": [{"kind": "keyword", "text": "struct"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "Button",
          "url": "/documentation/swiftui/button"
        },
        "doc://text": {
          "fragments": [{"kind": "keyword", "text": "struct"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "Text",
          "url": "/documentation/swiftui/text"
        },
        "doc://styles": {
          "kind": "article",
          "role": "collectionGroup",
          "title": "Styles",
          "url": "/documentation/swiftui/styles"
        }
      }
    }
    """.utf8
)

private let stylesSearchPage = Data(
    """
    {
      "references": {
        "doc://button-duplicate": {
          "fragments": [{"kind": "keyword", "text": "struct"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "Button",
          "url": "/documentation/swiftui/button"
        },
        "doc://button-style": {
          "fragments": [{"kind": "keyword", "text": "protocol"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "ButtonStyle",
          "url": "/documentation/swiftui/buttonstyle"
        }
      }
    }
    """.utf8
)

private struct SearchTestTransport: HTTPDataTransport {
    let responses: [URL: Data]

    func data(from url: URL) async throws -> (Data, URLResponse) {
        guard let data = responses[url] else {
            throw SearchTestError.unexpectedURL(url)
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }
}

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

private let cryptoKitRootData = Data(
    """
    {
      "references": {
        "doc://aes": {
          "fragments": [{"kind": "keyword", "text": "enum"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "AES",
          "url": "/documentation/cryptokit/aes"
        }
      }
    }
    """.utf8
)

private struct SearchFallbackTransport: HTTPDataTransport {
    struct Response: Sendable {
        let statusCode: Int
        let data: Data
    }

    let responses: [URL: Response]

    func data(from url: URL) async throws -> (Data, URLResponse) {
        guard let result = responses[url] else {
            throw SearchTestError.unexpectedURL(url)
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

private enum SearchTestError: Error {
    case unexpectedURL(URL)
}
