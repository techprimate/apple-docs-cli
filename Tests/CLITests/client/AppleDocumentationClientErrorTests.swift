import Foundation
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Apple documentation client errors")
struct AppleDocumentationClientErrorTests {
    @Test("maps a missing type to discovery guidance")
    func mapsMissingTypeToDiscoveryGuidance() async throws {
        // -- Arrange --
        let typeURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftdata/model.json")
        )
        let technologiesURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/technologies.json")
        )
        let rootURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swiftdata.json")
        )
        let client = DefaultAppleDocumentationClient(
            dependencies: LookupTestTransport(
                responses: [
                    typeURL: .init(statusCode: 404, data: Data()),
                    technologiesURL: .init(statusCode: 200, data: swiftDataCatalogData),
                    rootURL: .init(statusCode: 200, data: modelRootData),
                ]
            )
        )

        // -- Act --
        do {
            _ = try await client.fetchType(named: "Model", technology: "SwiftData")
            Issue.record("Expected the request to fail")
        } catch {
            // -- Assert --
            #expect(
                error.localizedDescription == """
                    No Apple documentation found for 'Model' in SwiftData.

                    Did you mean:
                      Model()
                      https://developer.apple.com/documentation/swiftdata/model()

                    Browse available types:
                      apple-docs types list --technology "SwiftData"
                      https://developer.apple.com/documentation/swiftdata
                    """
            )
        }
    }
}

private let swiftDataCatalogData = Data(
    """
    {
      "sections": [{
        "groups": [{
          "technologies": [{
            "destination": {
              "identifier": "doc://com.apple.documentation/documentation/SwiftData"
            },
            "title": "SwiftData"
          }]
        }]
      }]
    }
    """.utf8
)

private let modelRootData = Data(
    """
    {
      "references": {
        "doc://model": {
          "fragments": [{"kind": "keyword", "text": "macro"}],
          "kind": "symbol",
          "role": "symbol",
          "title": "Model()",
          "url": "/documentation/swiftdata/model()"
        }
      }
    }
    """.utf8
)

private struct LookupTestTransport: HTTPDataTransport {
    struct Response: Sendable {
        let statusCode: Int
        let data: Data
    }

    let responses: [URL: Response]

    func data(from url: URL) async throws -> (Data, URLResponse) {
        guard let result = responses[url] else {
            throw LookupTestError.unexpectedURL(url)
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

private enum LookupTestError: Error {
    case unexpectedURL(URL)
}
