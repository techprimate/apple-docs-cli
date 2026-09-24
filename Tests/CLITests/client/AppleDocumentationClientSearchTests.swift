import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Apple documentation type search client")
struct AppleDocumentationClientSearchTests {
    @available(macOS 15, *)
    @Test("detailed search returns partial-result paths and successful matches")
    func reportsPartialResults() async throws {
        // -- Arrange --
        let rootURL = try searchURL("swiftui")
        let controlsURL = try searchURL("swiftui/controls")
        let stylesURL = try searchURL("swiftui/styles")
        let transport = HTTPTestTransport(responses: [
            rootURL: .http(data: partialFailureRootSearchPage),
            controlsURL: .http(statusCode: 404, data: Data()), stylesURL: .http(data: stylesSearchPage),
        ])
        let recorder = ClientLogRecorder()
        let client = DefaultAppleDocumentationClient(logger: recorder.logger(), dependencies: transport)

        // -- Act --
        let result = try await client.searchTypes(query: "buttonstyle", technology: "SwiftUI")

        // -- Assert --
        #expect(result.types.map(\.name) == ["ButtonStyle"])
        #expect(result.unavailableCollectionPaths == ["/documentation/swiftui/controls"])
        #expect(Set(await transport.requestedURLs) == Set([rootURL, controlsURL, stylesURL]))
        let coverage = try #require(recorder.events.first { $0.message.description == "Documentation search coverage" })
        #expect(coverage.level == .debug)
        #expect(coverage.metadata?["unavailable"]?.description == "1")
        #expect(coverage.metadata?["query"] == nil)
    }

    @Test("detailed search treats no matches as a successful empty result")
    func returnsEmptyResults() async throws {
        // -- Arrange --
        let rootURL = try searchURL("swiftui")
        let transport = HTTPTestTransport(responses: [rootURL: .http(data: duplicateRootSearchPage)])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport
        )

        // -- Act --
        let result = try await client.searchTypes(query: "Missing", technology: "SwiftUI")

        // -- Assert --
        #expect(result.types.isEmpty)
        #expect(result.unavailableCollectionPaths.isEmpty)
        #expect(await transport.requestedURLs == [rootURL])
    }

    @Test("collection cancellation propagates instead of returning partial results", arguments: [true, false])
    func propagatesCancellation(urlCancellation: Bool) async throws {
        // -- Arrange --
        let rootURL = try searchURL("swiftui")
        let controlsURL = try searchURL("swiftui/controls")
        let error: any Error = urlCancellation ? URLError(.cancelled) : CancellationError()
        let transport = HTTPTestTransport(responses: [
            rootURL: .http(data: rootSearchPage), controlsURL: .failure(error),
        ])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport
        )

        // -- Act --
        await #expect(throws: CancellationError.self) {
            try await client.searchTypes(query: "View", technology: "SwiftUI")
        }

        // -- Assert --
        #expect(await transport.requestedURLs == [rootURL, controlsURL])
    }

    private func searchURL(_ path: String) throws -> URL {
        try #require(URL(string: "https://developer.apple.com/tutorials/data/documentation/\(path).json"))
    }

    @Test("searches symbols across nested collection groups")
    func searchesCollectionGroups() async throws {
        // -- Arrange --
        let rootURL = try searchURL("swiftui")
        let controlsURL = try searchURL("swiftui/controls")
        let stylesURL = try searchURL("swiftui/styles")
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [
                rootURL: .http(data: rootSearchPage), controlsURL: .http(data: controlsSearchPage),
                stylesURL: .http(data: stylesSearchPage),
            ])
        )

        // -- Act --
        let types = try await client.searchTypes(query: "button", technology: "SwiftUI")

        // -- Assert --
        #expect(types.types.map(\.name) == ["Button", "ButtonStyle"])
        #expect(types.types.map(\.path) == ["button", "buttonstyle"])
    }

    @Test("deduplicates root symbols with the same path")
    func deduplicatesRootSymbols() async throws {
        // -- Arrange --
        let rootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftui.json")
        )
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(
                responses: [rootURL: .http(data: duplicateRootSearchPage)]
            )
        )

        // -- Act --
        let types = try await client.searchTypes(query: "button", technology: "SwiftUI")

        // -- Assert --
        #expect(types.types.map(\.name) == ["Button"])
        #expect(types.types.map(\.path) == ["button"])
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
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(
                responses: [
                    rootURL: .http(statusCode: 200, data: partialFailureRootSearchPage),
                    controlsURL: .http(statusCode: 404, data: Data()),
                    stylesURL: .http(statusCode: 200, data: stylesSearchPage),
                ]
            )
        )

        // -- Act --
        let types = try await client.searchTypes(query: "buttonstyle", technology: "SwiftUI")

        // -- Assert --
        #expect(types.types.map(\.name) == ["ButtonStyle"])
        #expect(types.types.map(\.path) == ["buttonstyle"])
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
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(
                responses: [
                    requestedRootURL: .http(statusCode: 404, data: Data()),
                    technologiesURL: .http(statusCode: 200, data: cryptoKitCatalogData),
                    resolvedRootURL: .http(statusCode: 200, data: cryptoKitRootData),
                ]
            )
        )

        // -- Act --
        let types = try await client.searchTypes(query: "AES", technology: "Apple CryptoKit")

        // -- Assert --
        #expect(types.types.map(\.name) == ["AES"])
        #expect(types.types.map(\.path) == ["aes"])
    }

    @Test("returns an empty result after searching all collections")
    func returnsEmptySearchAfterTraversal() async throws {
        // -- Arrange --
        let transport = HTTPTestTransport(responses: [
            try searchURL("swiftui"): .http(data: rootSearchPage),
            try searchURL("swiftui/controls"): .http(data: controlsSearchPage),
            try searchURL("swiftui/styles"): .http(data: stylesSearchPage),
        ])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport)

        // -- Act --
        let result = try await client.searchTypes(query: "Picker", technology: "SwiftUI")

        // -- Assert --
        #expect(result.types.isEmpty)
        #expect(result.unavailableCollectionPaths.isEmpty)
        #expect(await transport.requestedURLs.count == 3)
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
