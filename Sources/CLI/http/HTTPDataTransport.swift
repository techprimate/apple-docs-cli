import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol HTTPDataTransport: Sendable {
        func data(from url: URL) async throws -> (Data, URLResponse)
    }

    #if canImport(FoundationNetworking)
        extension URLSession: HTTPDataTransport {
            func data(from url: URL) async throws -> (Data, URLResponse) {
                try await data(from: url, delegate: nil)
            }
        }
    #else
        extension URLSession: HTTPDataTransport {}
    #endif

    typealias DefaultAppleDocumentationClientDependencies = HTTPDataTransport
#else
    typealias DefaultAppleDocumentationClientDependencies = URLSession
#endif
