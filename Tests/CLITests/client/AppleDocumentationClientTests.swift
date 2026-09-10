import Foundation
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Apple documentation client")
struct AppleDocumentationClientTests {
    @Test("requests and decodes a type documentation page")
    func fetchesTypeDocumentation() async throws {
        let expectedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/metrickit/mxhangdiagnostic.json")
        )
        let response = try #require(
            HTTPURLResponse(
                url: expectedURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
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
        let transport = TypePageTransport(
            expectedURL: expectedURL,
            response: response,
            data: data
        )
        let client = DefaultAppleDocumentationClient(dependencies: transport)

        let document = try await client.fetchType(
            named: "MXHangDiagnostic",
            technology: "MetricKit"
        )

        #expect(document.data == data)
    }

    @Test("preserves a successful response that the text renderer cannot decode")
    func preservesUndecodableResponse() async throws {
        // -- Arrange --
        let expectedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/swift/string.json")
        )
        let response = try #require(
            HTTPURLResponse(
                url: expectedURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        )
        let data = Data("{\"newUpstreamShape\":true}".utf8)
        let client = DefaultAppleDocumentationClient(
            dependencies: TypePageTransport(
                expectedURL: expectedURL,
                response: response,
                data: data
            )
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
                string:
                    "https://developer.apple.com/tutorials/data/documentation/foundation/urlsession/asyncbytes.json"
            )
        )
        let response = try #require(
            HTTPURLResponse(
                url: expectedURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        )
        let client = DefaultAppleDocumentationClient(
            dependencies: TypePageTransport(
                expectedURL: expectedURL,
                response: response,
                data: Data("{}".utf8)
            )
        )

        // -- Act --
        _ = try await client.fetchType(named: name, technology: "Foundation")

        // -- Assert --
        // The transport rejects any request that does not use the expected nested URL.
    }

    @Test("reports unsuccessful documentation responses")
    func reportsHTTPError() async throws {
        let expectedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/metrickit/missingtype.json")
        )
        let response = try #require(
            HTTPURLResponse(
                url: expectedURL,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let client = DefaultAppleDocumentationClient(
            dependencies: TypePageTransport(
                expectedURL: expectedURL,
                response: response,
                data: Data("Not Found".utf8)
            )
        )

        do {
            _ = try await client.fetchType(named: "MissingType", technology: "MetricKit")
            Issue.record("Expected the request to fail")
        } catch let error as DefaultAppleDocumentationClient<TypePageTransport>.Error {
            #expect(error == .httpStatus(500))
        }
    }
}

private struct TypePageTransport: HTTPDataTransport {
    let expectedURL: URL
    let response: URLResponse
    let data: Data

    func data(from url: URL) async throws -> (Data, URLResponse) {
        guard url == expectedURL else {
            throw TestTransportError.unexpectedURL(url)
        }
        return (data, response)
    }
}

private enum TestTransportError: Error {
    case unexpectedURL(URL)
}
