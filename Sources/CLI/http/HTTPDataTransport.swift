import Foundation

#if DEBUG
    protocol HTTPDataTransport: Sendable {
        func data(from url: URL) async throws -> (Data, URLResponse)
    }

    extension URLSession: HTTPDataTransport {}

    typealias DefaultAppleDocumentationClientDependencies = HTTPDataTransport
#else
    typealias DefaultAppleDocumentationClientDependencies = URLSession
#endif
