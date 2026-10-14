import Foundation
import Logging

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol AppleDocumentationClient: Sendable {
        func fetchDocument(at destination: DocumentationDestination) async throws -> TypeDocumentationDocument
        func fetchTechnologyCatalog() async throws -> TechnologyCatalogPageDTO
    }
    extension DefaultAppleDocumentationClient: AppleDocumentationClient {}
#else
    typealias AppleDocumentationClient = DefaultAppleDocumentationClient<URLSession>
#endif

final class DefaultAppleDocumentationClient<Dependencies: DefaultAppleDocumentationClientDependencies>: Sendable {
    private static var defaultBaseURL: URL {
        guard let url = URL(string: "https://developer.apple.com/tutorials/data/") else {
            preconditionFailure("Invalid base URL for documentation client")
        }
        return url
    }

    let logger: Logger
    private let dependencies: Dependencies
    private let baseURL: URL

    init(
        logger: Logger,
        dependencies: Dependencies,
        baseURL: URL = defaultBaseURL
    ) {
        self.logger = logger
        self.dependencies = dependencies
        self.baseURL = baseURL
        logger.trace("Initialized documentation client", metadata: ["path": .string(baseURL.path)])
    }

    func fetchDocument(at destination: DocumentationDestination) async throws -> TypeDocumentationDocument {
        var url = baseURL
        for component in destination.path.split(separator: "/") {
            url.append(component: component)
        }
        url.appendPathExtension("json")
        return TypeDocumentationDocument(data: try await fetchData(from: url), destination: destination)
    }

    func fetchTechnologyCatalog() async throws -> TechnologyCatalogPageDTO {
        let url = baseURL.appending(component: "documentation")
            .appending(component: "technologies").appendingPathExtension("json")
        let data = try await fetchData(from: url)
        do {
            return try JSONDecoder().decode(TechnologyCatalogPageDTO.self, from: data)
        } catch {
            logger.error("Failed to decode technology catalog", metadata: ["path": .string(url.path)])
            throw error
        }
    }

    private func fetchData(from url: URL) async throws -> Data {
        let started = ContinuousClock.now
        logger.debug("Requesting documentation data", metadata: ["path": .string(url.path)])
        defer {
            logger.debug(
                "Documentation request finished",
                metadata: [
                    "path": .string(url.path), "elapsed": .string("\(started.duration(to: .now))"),
                ])
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await dependencies.data(from: url)
        } catch {
            let cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled
            logger.log(
                level: cancelled ? .debug : .error, "Documentation transport failed",
                metadata: [
                    "path": .string(url.path), "error_type": .string(String(reflecting: type(of: error))),
                ])
            throw error
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid documentation response", metadata: ["path": .string(url.path)])
            throw AppleDocumentationClientError.invalidResponse
        }
        let metadata: Logger.Metadata = [
            "path": .string(url.path), "status": .stringConvertible(httpResponse.statusCode),
            "bytes": .stringConvertible(data.count),
        ]
        logger.debug("Received documentation response", metadata: metadata)
        guard (200..<300).contains(httpResponse.statusCode) else {
            let level: Logger.Level =
                httpResponse.statusCode == 404
                ? .debug
                : (httpResponse.statusCode >= 500 ? .error : .warning)
            logger.log(level: level, "Documentation request rejected", metadata: metadata)
            throw AppleDocumentationClientError.httpStatus(httpResponse.statusCode)
        }
        return data
    }

}
