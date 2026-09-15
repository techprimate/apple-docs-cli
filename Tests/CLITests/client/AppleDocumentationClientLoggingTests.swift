import Foundation
import Logging
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Apple documentation client logging")
struct AppleDocumentationClientLoggingTests {
    @available(macOS 15, *)
    @Test("logs successful requests without exposing response bodies or URL credentials")
    func logsSuccessfulRequest() async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let url = try #require(URL(string: "https://user:secret@example.com/data/"))
        let data = Data("private response body".utf8)
        let client = DefaultAppleDocumentationClient(
            logger: recorder.logger(),
            dependencies: LoggingTestTransport(result: .success((data, try response(status: 200)))),
            baseURL: url
        )

        // -- Act --
        let document = try await client.fetchType(named: "String", technology: "Swift")

        // -- Assert --
        #expect(document.data == data)
        let events = recorder.events
        #expect(events.contains { $0.level == .trace })
        let received = try #require(events.first { $0.message.description == "Received documentation response" })
        #expect(received.level == .debug)
        #expect(received.metadata?["status"]?.description == "200")
        #expect(received.metadata?["bytes"]?.description == "21")
        #expect(received.metadata?["path"]?.description == "/data/documentation/swift/string.json")
        #expect(events.contains { $0.level == .info && $0.message.description == "Fetched type documentation" })
        #expect(events.contains { $0.metadata?["elapsed"] != nil })
        #expect(!events.contains { $0.level >= .warning })
        for event in events {
            let output = "\(event.message) \(event.metadata ?? [:])"
            #expect(!output.contains("private response body"))
            #expect(!output.contains("secret"))
            #expect(!output.contains("user:"))
        }
    }

    @available(macOS 15, *)
    @Test("classifies HTTP failures without changing the thrown error", arguments: [404, 429, 500])
    func logsHTTPFailure(status: Int) async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let client = DefaultAppleDocumentationClient(
            logger: recorder.logger(),
            dependencies: LoggingTestTransport(result: .success((Data(), try response(status: status))))
        )
        let expectedLevel: Logger.Level = status == 404 ? .debug : (status >= 500 ? .error : .warning)

        // -- Act --
        await #expect(throws: DefaultAppleDocumentationClient<LoggingTestTransport>.Error.httpStatus(status)) {
            try await client.fetchDocumentationPage(path: "/documentation/swift")
        }

        // -- Assert --
        let event = try #require(recorder.events.first { $0.message.description == "Documentation request rejected" })
        #expect(event.level == expectedLevel)
        #expect(event.metadata?["status"]?.description == String(status))
        #expect(event.metadata?["path"]?.description == "/tutorials/data/documentation/swift.json")
        #expect(!recorder.events.contains { $0.level > expectedLevel })
    }

    @available(macOS 15, *)
    @Test(
        "logs transport failures but treats cancellation as debug", arguments: [URLError.timedOut, URLError.cancelled])
    func logsTransportFailure(code: URLError.Code) async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let client = DefaultAppleDocumentationClient(
            logger: recorder.logger(),
            dependencies: LoggingTestTransport(result: .failure(URLError(code)))
        )

        // -- Act --
        await #expect(throws: URLError(code)) {
            try await client.fetchType(named: "String", technology: "Swift")
        }

        // -- Assert --
        let event = try #require(recorder.events.first { $0.message.description == "Documentation transport failed" })
        #expect(event.level == (code == .cancelled ? .debug : .error))
        #expect(!recorder.events.contains { $0.level == .info })
    }

    @available(macOS 15, *)
    @Test("logs invalid non-HTTP responses as errors")
    func logsInvalidResponse() async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let url = try #require(URL(string: "https://example.com"))
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        let client = DefaultAppleDocumentationClient(
            logger: recorder.logger(),
            dependencies: LoggingTestTransport(result: .success((Data(), response)))
        )

        // -- Act --
        await #expect(throws: DefaultAppleDocumentationClient<LoggingTestTransport>.Error.invalidResponse) {
            try await client.fetchType(named: "String", technology: "Swift")
        }

        // -- Assert --
        #expect(
            recorder.events.contains {
                $0.level == .error && $0.message.description == "Invalid documentation response"
            })
    }

    @available(macOS 15, *)
    @Test("logs decoding failures without leaking the malformed body", arguments: [false, true])
    func logsDecodingFailure(catalog: Bool) async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let client = DefaultAppleDocumentationClient(
            logger: recorder.logger(),
            dependencies: LoggingTestTransport(
                result: .success((Data("sensitive malformed body".utf8), try response(status: 200)))
            )
        )

        // -- Act --
        await #expect(throws: DecodingError.self) {
            if catalog {
                _ = try await client.fetchTechnologies()
            } else {
                _ = try await client.fetchDocumentationPage(path: "/documentation/swift")
            }
        }

        // -- Assert --
        #expect(recorder.events.contains { $0.level == .error })
        #expect(
            !recorder.events.contains { "\($0.message) \($0.metadata ?? [:])".contains("sensitive malformed body") })
        #expect(!recorder.events.contains { $0.level == .info })
    }

    @available(macOS 15, *)
    @Test("logs empty searches as expected outcomes rather than failures")
    func logsEmptySearch() async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let client = DefaultAppleDocumentationClient(
            logger: recorder.logger(),
            dependencies: LoggingTestTransport(
                result: .success((Data("{\"references\":{}}".utf8), try response(status: 200)))
            )
        )

        // -- Act --
        await #expect(
            throws: DefaultAppleDocumentationClient<LoggingTestTransport>.Error.typeSearchNoResults(
                query: "Missing", technology: "Swift", technologyURL: "https://developer.apple.com/documentation/swift"
            )
        ) {
            try await client.searchTypes(query: "Missing", technology: "Swift")
        }

        // -- Assert --
        #expect(
            recorder.events.contains {
                $0.level == .notice && $0.message.description == "No matching documentation types"
            })
        #expect(!recorder.events.contains { $0.level >= .warning })
    }

    @available(macOS 15, *)
    @Test("warns about skipped collection groups while returning available search results")
    func logsPartialSearch() async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let root = """
            {"references":{
              "button":{"kind":"symbol","role":"symbol","title":"Button","url":"/documentation/swiftui/button"},
              "controls":{"role":"collectionGroup","url":"/documentation/swiftui/controls"}
            }}
            """
        let client = DefaultAppleDocumentationClient(
            logger: recorder.logger(),
            dependencies: LoggingSearchTransport(responses: [
                "/tutorials/data/documentation/swiftui.json": (200, root),
                "/tutorials/data/documentation/swiftui/controls.json": (404, ""),
            ])
        )

        // -- Act --
        let types = try await client.searchTypes(query: "button", technology: "SwiftUI")

        // -- Assert --
        #expect(types.map(\.name) == ["Button"])
        let skipped = try #require(
            recorder.events.first { $0.message.description == "Skipping unavailable collection group" })
        #expect(skipped.level == .warning)
        #expect(skipped.metadata?["path"]?.description == "/documentation/swiftui/controls")
        let completed = try #require(
            recorder.events.first { $0.message.description == "Documentation search completed" })
        #expect(completed.level == .info)
        #expect(completed.metadata?["matches"]?.description == "1")
        #expect(!recorder.events.contains { $0.level >= .error })
    }

    @available(macOS 15, *)
    @Test("logs canonical type retries without reporting an error for the initial miss")
    func logsCanonicalRetry() async throws {
        // -- Arrange --
        let recorder = ClientLogRecorder()
        let catalog = """
            {"sections":[{"groups":[{"technologies":[{
              "title":"Apple CryptoKit",
              "destination":{"identifier":"doc://com.apple.documentation/documentation/CryptoKit"}
            }]}]}]}
            """
        let client = DefaultAppleDocumentationClient(
            logger: recorder.logger(),
            dependencies: LoggingSearchTransport(responses: [
                "/tutorials/data/documentation/apple cryptokit/aes.json": (404, ""),
                "/tutorials/data/documentation/technologies.json": (200, catalog),
                "/tutorials/data/documentation/cryptokit/aes.json": (200, "raw document"),
            ])
        )

        // -- Act --
        let document = try await client.fetchType(named: "AES", technology: "Apple CryptoKit")

        // -- Assert --
        #expect(document.data == Data("raw document".utf8))
        let retry = try #require(
            recorder.events.first { $0.message.description == "Retrying type with canonical technology" })
        #expect(retry.level == .debug)
        #expect(retry.metadata?["slug"]?.description == "CryptoKit")
        #expect(
            recorder.events.contains { $0.level == .info && $0.message.description == "Fetched type documentation" })
        #expect(!recorder.events.contains { $0.level >= .warning })
    }

    private func response(status: Int) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://example.com"))
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
    }
}

private struct LoggingSearchTransport: HTTPDataTransport {
    let responses: [String: (Int, String)]

    func data(from url: URL) async throws -> (Data, URLResponse) {
        let (status, body) = try #require(responses[url.path])
        let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
        return (Data(body.utf8), response)
    }
}

private struct LoggingTestTransport: HTTPDataTransport {
    let result: Result<(Data, URLResponse), Swift.Error>

    func data(from _: URL) async throws -> (Data, URLResponse) {
        try result.get()
    }
}
