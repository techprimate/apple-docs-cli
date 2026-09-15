import Foundation
import Testing

@Suite("HTTP test transport")
struct HTTPTestTransportTests {
    @Test("reports unexpected requests even when the caller catches the error")
    func reportsUnexpectedRequests() async throws {
        // -- Arrange --
        let url = try #require(URL(string: "https://example.com/unstubbed"))
        let transport = HTTPTestTransport(responses: [:])

        // -- Act --
        await withKnownIssue("Unstubbed requests must fail the calling test") {
            _ = try? await transport.data(from: url)
        }

        // -- Assert --
        #expect(await transport.requestedURLs == [url])
    }
}
