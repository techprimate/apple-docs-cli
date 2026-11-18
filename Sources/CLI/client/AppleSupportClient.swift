import Foundation
import Logging

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol AppleSupportClient: Sendable {
        func fetchHTML(at destination: SupportDestination) async throws -> SupportHTMLDocument
        func fetchDocument(at destination: SupportDestination) async throws -> SupportDocumentResponse
    }
    extension DefaultAppleSupportClient: AppleSupportClient {}
    typealias DefaultAppleSupportClientDependencies = HTTPDataTransport
#else
    typealias AppleSupportClient = DefaultAppleSupportClient<URLSession>
    typealias DefaultAppleSupportClientDependencies = URLSession
#endif

enum SupportDocumentResponse: Equatable, Sendable {
    case html(SupportHTMLDocument)
    case pdf(URL)
}

struct SupportHTMLDocument: Equatable, Sendable {
    let destination: SupportDestination
    let html: String
    let responseByteCount: Int
}

final class DefaultAppleSupportClient<Dependencies: DefaultAppleSupportClientDependencies>: Sendable {
    private let logger: Logger
    private let dependencies: Dependencies

    init(logger: Logger, dependencies: Dependencies) {
        self.logger = logger
        self.dependencies = dependencies
    }

    func fetchHTML(at destination: SupportDestination) async throws -> SupportHTMLDocument {
        switch try await fetchDocument(at: destination) {
        case .html(let document): return document
        case .pdf: throw AppleSupportClientError.unsupportedContentType("application/pdf")
        }
    }

    func fetchDocument(at destination: SupportDestination) async throws -> SupportDocumentResponse {
        logger.debug("Requesting support document", metadata: ["path": .string(destination.path)])
        let (data, response) = try await dependencies.data(from: destination.url)
        guard let response = response as? HTTPURLResponse, let responseURL = response.url else {
            throw AppleSupportClientError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw AppleSupportClientError.httpStatus(response.statusCode)
        }
        let resolved = try SupportDestination(responseURL: responseURL)
        let contentType = response.mimeType?.lowercased()
        if contentType == "application/pdf" { return .pdf(resolved.url) }
        guard contentType == "text/html" || contentType == "application/xhtml+xml" else {
            throw AppleSupportClientError.unsupportedContentType(contentType)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw AppleSupportClientError.invalidEncoding
        }
        logger.debug(
            "Received support HTML",
            metadata: ["path": .string(resolved.path), "bytes": .stringConvertible(data.count)])
        return .html(SupportHTMLDocument(destination: resolved, html: html, responseByteCount: data.count))
    }
}
