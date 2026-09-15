import Foundation
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

actor HTTPTestTransport: HTTPDataTransport {
    enum Response: Sendable {
        case http(statusCode: Int = 200, data: Data)
        case response(data: Data, response: URLResponse)
        case failure(any Error)
    }

    private let responses: [URL: Response]
    private(set) var requestedURLs: [URL] = []

    init(responses: [URL: Response]) {
        self.responses = responses
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        requestedURLs.append(url)
        let response = try #require(responses[url], "Unexpected request: \(url)")
        switch response {
        case .http(let statusCode, let data):
            let response = try #require(
                HTTPURLResponse(
                    url: url, statusCode: statusCode, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (data, response)
        case .response(let data, let response):
            return (data, response)
        case .failure(let error):
            throw error
        }
    }
}
