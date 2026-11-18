import Foundation
import Logging
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Apple support HTML client")
struct AppleSupportClientTests {
    @Test("fetches an HTML document without a DocC JSON suffix")
    func fetchesHTML() async throws {
        // -- Arrange --
        let destination = try SupportDestination(path: "help/glossary")
        let url = try #require(URL(string: "https://developer.apple.com/help/glossary/"))
        let data = Data("<main><h1>Glossary</h1></main>".utf8)
        let response = try #require(
            HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=UTF-8"]))
        let transport = HTTPTestTransport(responses: [url: .response(data: data, response: response)])
        let client = DefaultAppleSupportClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport)

        // -- Act --
        let document = try await client.fetchHTML(at: destination)

        // -- Assert --
        #expect(document.html == "<main><h1>Glossary</h1></main>")
        #expect(document.destination.path == "help/glossary")
        #expect(document.responseByteCount == data.count)
        #expect(await transport.requestedURLs == [url])
    }

    @Test("rejects HTTP errors before attempting HTML decoding", arguments: [404, 429, 500])
    func rejectsHTTPStatus(status: Int) async throws {
        // -- Arrange --
        let destination = try SupportDestination(path: "support/articles")
        let transport = HTTPTestTransport(responses: [destination.url: .http(statusCode: status, data: Data())])
        let client = DefaultAppleSupportClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport)

        // -- Act --
        let fetch = { try await client.fetchHTML(at: destination) }

        // -- Assert --
        await #expect(throws: AppleSupportClientError.httpStatus(status)) { try await fetch() }
    }

    @Test("rejects non-HTML responses", arguments: ["application/json", "application/pdf", "text/plain"])
    func rejectsContentType(contentType: String) async throws {
        // -- Arrange --
        let destination = try SupportDestination(path: "support/terms")
        let response = try #require(
            HTTPURLResponse(
                url: destination.url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": contentType]))
        let client = DefaultAppleSupportClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [
                destination.url: .response(data: Data("not HTML".utf8), response: response)
            ]))

        // -- Act --
        let fetch = { try await client.fetchHTML(at: destination) }

        // -- Assert --
        await #expect(throws: AppleSupportClientError.unsupportedContentType(contentType)) { try await fetch() }
    }

    @Test("keeps a validated redirect destination")
    func followsDeveloperRedirect() async throws {
        // -- Arrange --
        let destination = try SupportDestination(path: "support/fee-waiver")
        let finalURL = try #require(URL(string: "https://developer.apple.com/help/account/membership/fee-waiver/"))
        let response = try #require(
            HTTPURLResponse(
                url: finalURL, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"]))
        let client = DefaultAppleSupportClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [
                destination.url: .response(data: Data("<main>Help</main>".utf8), response: response)
            ]))

        // -- Act --
        let document = try await client.fetchHTML(at: destination)

        // -- Assert --
        #expect(document.destination.path == "help/account/membership/fee-waiver")
    }

    @Test(
        "rejects redirects outside supported developer paths",
        arguments: [
            "https://example.com/help/glossary/", "http://developer.apple.com/help/glossary/",
            "https://developer.apple.com/account/", "https://developer.apple.com:444/help/glossary/",
        ])
    func rejectsRedirect(raw: String) async throws {
        // -- Arrange --
        let destination = try SupportDestination(path: "help/glossary")
        let url = try #require(URL(string: raw))
        let response = try #require(
            HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"]))
        let client = DefaultAppleSupportClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [
                destination.url: .response(data: Data("<main>Help</main>".utf8), response: response)
            ]))

        // -- Act --
        let fetch = { try await client.fetchHTML(at: destination) }

        // -- Assert --
        await #expect(throws: AppleSupportClientError.invalidResponse) { try await fetch() }
    }

    @Test("rejects non-HTTP responses and invalid UTF-8")
    func rejectsInvalidResponses() async throws {
        // -- Arrange --
        let destination = try SupportDestination(path: "help/glossary")
        let response = URLResponse(
            url: destination.url, mimeType: "text/html", expectedContentLength: 0,
            textEncodingName: nil)
        let client = DefaultAppleSupportClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [destination.url: .response(data: Data(), response: response)]))
        let httpResponse = try #require(
            HTTPURLResponse(
                url: destination.url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"]))
        let invalidUTF8Client = DefaultAppleSupportClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [
                destination.url: .response(data: Data([0xFF]), response: httpResponse)
            ]))

        // -- Act --
        let fetch = { try await client.fetchHTML(at: destination) }
        let fetchInvalidUTF8 = { try await invalidUTF8Client.fetchHTML(at: destination) }

        // -- Assert --
        await #expect(throws: AppleSupportClientError.invalidResponse) { try await fetch() }
        await #expect(throws: AppleSupportClientError.invalidEncoding) { try await fetchInvalidUTF8() }
    }

    @Test("preserves transport cancellation")
    func preservesCancellation() async throws {
        // -- Arrange --
        let destination = try SupportDestination(path: "help/glossary")
        let client = DefaultAppleSupportClient(
            logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
            dependencies: HTTPTestTransport(responses: [destination.url: .failure(CancellationError())]))

        // -- Act --
        let fetch = { try await client.fetchHTML(at: destination) }

        // -- Assert --
        await #expect(throws: CancellationError.self) { try await fetch() }
    }
}
