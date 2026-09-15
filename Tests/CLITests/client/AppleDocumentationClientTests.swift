import Foundation
import Logging
import Testing

@testable import CLI

@Suite("Apple documentation client")
struct AppleDocumentationClientTests {
    @Test("requests and decodes a type documentation page")
    func fetchesTypeDocumentation() async throws {
        // -- Arrange --
        let expectedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/metrickit/mxhangdiagnostic.json")
        )
        let data = Data(
            """
            {
              "abstract": [{"text": "A diagnostic report.", "type": "text"}],
              "metadata": {
                "modules": [{"name": "MetricKit"}],
                "platforms": [],
                "roleHeading": "Class",
                "symbolKind": "class",
                "title": "MXHangDiagnostic"
              },
              "primaryContentSections": [],
              "references": {}
            }
            """.utf8
        )
        let transport = HTTPTestTransport(responses: [expectedURL: .http(data: data)])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: transport
        )

        // -- Act --
        let document = try await client.fetchType(named: "MXHangDiagnostic", technology: "MetricKit")

        // -- Assert --
        #expect(document.data == data)
        #expect(await transport.requestedURLs == [expectedURL])
    }

    @Test("preserves a successful response that the text renderer cannot decode")
    func preservesUndecodableResponse() async throws {
        // -- Arrange --
        let expectedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swift/string.json")
        )
        let data = Data("{\"newUpstreamShape\":true}".utf8)
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [expectedURL: .http(data: data)])
        )

        // -- Act --
        let document = try await client.fetchType(named: "String", technology: "Swift")

        // -- Assert --
        #expect(document.data == data)
    }

    @Test(
        "resolves nested type names as documentation path components",
        arguments: ["URLSession.AsyncBytes", "URLSession/AsyncBytes"]
    )
    func resolvesNestedTypePath(name: String) async throws {
        // -- Arrange --
        let expectedURL = try #require(
            URL(
                string: "https://developer.apple.com/tutorials/data/documentation/foundation/urlsession/asyncbytes.json"
            )
        )
        let transport = HTTPTestTransport(responses: [expectedURL: .http(data: Data("{}".utf8))])
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: transport
        )

        // -- Act --
        _ = try await client.fetchType(named: name, technology: "Foundation")

        // -- Assert --
        #expect(await transport.requestedURLs == [expectedURL])
    }

    @Test("reports unsuccessful documentation responses")
    func reportsHTTPError() async throws {
        // -- Arrange --
        let expectedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/metrickit/missingtype.json")
        )
        let client = DefaultAppleDocumentationClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(
                responses: [expectedURL: .http(statusCode: 500, data: Data("Not Found".utf8))]
            )
        )

        // -- Act --
        do {
            _ = try await client.fetchType(named: "MissingType", technology: "MetricKit")
            Issue.record("Expected the request to fail")
        } catch let error as DefaultAppleDocumentationClient<HTTPTestTransport>.Error {
            // -- Assert --
            #expect(error == .httpStatus(500))
        }
    }
}
