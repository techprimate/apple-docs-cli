import Foundation
import Testing

@testable import CLI

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
        #expect(document.page.metadata.title == "MXHangDiagnostic")
        #expect(document.page.metadata.modules.map(\.name) == ["MetricKit"])
        #expect(document.page.abstract.first?.text == "A diagnostic report.")
    }

    @Test("reports unsuccessful documentation responses")
    func reportsHTTPError() async throws {
        let expectedURL = try #require(
            URL(string: "https://developer.apple.com/tutorials/data/documentation/metrickit/missingtype.json")
        )
        let response = try #require(
            HTTPURLResponse(
                url: expectedURL,
                statusCode: 404,
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
            #expect(error == .httpStatus(404))
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
