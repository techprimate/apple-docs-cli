import Foundation
import Logging

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if DEBUG
    protocol AppleDocumentationClient: Sendable {
        func fetchType(named name: String, technology: String) async throws -> TypeDocumentationDocument
    }
    extension DefaultAppleDocumentationClient: AppleDocumentationClient {}
#else
    typealias AppleDocumentationClient = DefaultAppleDocumentationClient<URLSession>
#endif

struct DefaultAppleDocumentationClient<Dependencies: DefaultAppleDocumentationClientDependencies>: Sendable {
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

    func fetchType(
        named name: String,
        technology: String
    ) async throws -> TypeDocumentationDocument {
        let metadata: Logger.Metadata = [
            "apple_docs.type": .string(name), "apple_docs.technology": .string(technology),
        ]
        logger.debug("Fetching type documentation", metadata: metadata)
        do {
            let document = TypeDocumentationDocument(
                data: try await fetchData(from: typeURL(name: name, technology: technology))
            )
            logger.info("Fetched type documentation", metadata: metadata)
            return document
        } catch Error.httpStatus(404) {
            logger.debug("Type path not found, resolving technology", metadata: metadata)
            let resolved = try await resolveTechnology(named: technology)
            guard let slug = resolved.documentationSlug else {
                logger.notice("Technology has no documentation root", metadata: metadata)
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }

            // Display names do not always match DocC path components, such as Apple CryptoKit.
            if slug.caseInsensitiveCompare(technology) != .orderedSame {
                logger.debug("Retrying type with canonical technology", metadata: ["slug": .string(slug)])
                do {
                    let document = TypeDocumentationDocument(
                        data: try await fetchData(from: typeURL(name: name, technology: slug))
                    )
                    logger.info("Fetched type documentation", metadata: metadata)
                    return document
                } catch Error.httpStatus(404) {
                    logger.debug("Canonical type path not found, looking for suggestions", metadata: metadata)
                }
            }

            let types = try await fetchTypesDirect(technology: slug)
            let normalizedName = normalizedSymbolName(name)
            let suggestion = types.first {
                normalizedSymbolName($0.name) == normalizedName
            }
            logger.notice("Type not found", metadata: ["suggestion_found": .stringConvertible(suggestion != nil)])
            throw Error.typeNotFound(
                name: name,
                technology: resolved.name,
                suggestion: suggestion,
                technologyURL: resolved.url
            )
        }
    }

    func fetchTypes(technology: String) async throws -> [DocumentationType] {
        logger.debug("Fetching documentation types", metadata: ["apple_docs.technology": .string(technology)])
        let root = try await fetchDocumentationRoot(technology: technology)
        let types = sortTypes(documentationTypes(in: root.page, technology: root.slug))
        logger.info(
            "Fetched documentation types",
            metadata: [
                "path": .string("/documentation/\(root.slug.lowercased())"),
                "count": .stringConvertible(types.count),
            ])
        return types
    }

    func fetchTechnologies() async throws -> [Technology] {
        logger.debug("Fetching technology catalog")
        let url = baseURL.appending(component: "documentation")
            .appending(component: "technologies")
            .appendingPathExtension("json")
        let data = try await fetchData(from: url)
        let page: TechnologyCatalogPageDTO
        do {
            page = try JSONDecoder().decode(TechnologyCatalogPageDTO.self, from: data)
        } catch {
            logger.error("Failed to decode technology catalog", metadata: ["path": .string(url.path)])
            throw error
        }
        let technologies = page.sections.flatMap(\.groups).flatMap(\.technologies).map {
            Technology(name: $0.title, identifier: $0.destination.identifier)
        }
        logger.info("Fetched technology catalog", metadata: ["count": .stringConvertible(technologies.count)])
        return technologies
    }

    private func fetchTypesDirect(technology: String) async throws -> [DocumentationType] {
        let path = "/documentation/\(technology.lowercased())"
        let page = try await fetchDocumentationPage(path: path)
        let types = sortTypes(documentationTypes(in: page, technology: technology))
        logger.info(
            "Fetched documentation types", metadata: ["path": .string(path), "count": .stringConvertible(types.count)])
        return types
    }

    func fetchDocumentationPage(path: String) async throws -> TechnologyDocumentationPageDTO {
        logger.debug("Fetching documentation page", metadata: ["path": .string(path)])
        var url = baseURL
        for component in path.split(separator: "/") {
            url.append(component: component)
        }
        url.appendPathExtension("json")
        let data = try await fetchData(from: url)
        do {
            let page = try JSONDecoder().decode(TechnologyDocumentationPageDTO.self, from: data)
            logger.trace(
                "Decoded documentation page", metadata: ["references": .stringConvertible(page.references.count)])
            return page
        } catch {
            logger.error("Failed to decode documentation page", metadata: ["path": .string(url.path)])
            throw error
        }
    }

    func documentationTypes(
        in page: TechnologyDocumentationPageDTO,
        technology: String
    ) -> [DocumentationType] {
        let pathPrefix = "/documentation/\(technology.lowercased())/"

        // Pages may reference articles and neighboring frameworks. Role and path filtering keeps
        // search results scoped to APIs in the requested technology.
        let types: [DocumentationType] = page.references.values.compactMap { reference in
            guard
                reference.kind == "symbol",
                reference.role == "symbol",
                let name = reference.title,
                let referencePath = reference.url,
                referencePath.lowercased().hasPrefix(pathPrefix)
            else {
                return nil
            }

            let path = String(referencePath.dropFirst(pathPrefix.count))
            let kind = reference.fragments?.first { $0.kind == "keyword" }?.text ?? "symbol"
            return DocumentationType(
                name: name,
                kind: kind,
                path: path,
                url: "https://developer.apple.com\(referencePath)"
            )
        }
        logger.trace(
            "Filtered documentation symbols",
            metadata: [
                "references": .stringConvertible(page.references.count), "count": .stringConvertible(types.count),
            ])
        return types
    }

    func sortTypes<S: Sequence>(_ types: S) -> [DocumentationType] where S.Element == DocumentationType {
        let sorted = types.sorted {
            let comparison = $0.name.compare($1.name, options: .caseInsensitive)
            return comparison == .orderedSame ? $0.path < $1.path : comparison == .orderedAscending
        }
        logger.trace("Sorted documentation types", metadata: ["count": .stringConvertible(sorted.count)])
        return sorted
    }

}

extension DefaultAppleDocumentationClient {
    struct DocumentationRoot: Sendable {
        let page: TechnologyDocumentationPageDTO
        let slug: String
        let name: String
        let url: String
    }

    func fetchDocumentationRoot(technology: String) async throws -> DocumentationRoot {
        do {
            return DocumentationRoot(
                page: try await fetchDocumentationPage(path: "/documentation/\(technology.lowercased())"),
                slug: technology,
                name: technology,
                url: "https://developer.apple.com/documentation/\(technology.lowercased())"
            )
        } catch Error.httpStatus(404) {
            logger.debug("Documentation root not found, resolving technology")
            let resolved = try await resolveTechnology(named: technology)
            guard let slug = resolved.documentationSlug else {
                logger.notice("Technology has no documentation root")
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
            guard slug.caseInsensitiveCompare(technology) != .orderedSame else {
                // Retrying the same case-insensitive path cannot produce a different result.
                logger.notice("Documentation root unavailable, skipping identical retry")
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
            logger.debug("Retrying documentation root with canonical technology", metadata: ["slug": .string(slug)])
            do {
                return DocumentationRoot(
                    page: try await fetchDocumentationPage(path: "/documentation/\(slug.lowercased())"),
                    slug: slug,
                    name: resolved.name,
                    url: resolved.url
                )
            } catch Error.httpStatus(404) {
                logger.notice("Canonical documentation root unavailable", metadata: ["slug": .string(slug)])
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
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
            throw Error.invalidResponse
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
            throw Error.httpStatus(httpResponse.statusCode)
        }
        return data
    }

    private func typeURL(name: String, technology: String) -> URL {
        var url = baseURL.appending(component: "documentation")
            .appending(component: technology.lowercased())
        // DocC uses path components for nested symbols while Swift spelling uses dots.
        for component in name.replacingOccurrences(of: ".", with: "/").split(separator: "/") {
            url.append(component: component.lowercased())
        }
        url.appendPathExtension("json")
        logger.trace("Resolved type documentation path", metadata: ["path": .string(url.path)])
        return url
    }

    func resolveTechnology(named requestedName: String) async throws -> ResolvedTechnology {
        logger.debug("Resolving technology", metadata: ["apple_docs.technology": .string(requestedName)])
        let technologies = try await fetchTechnologies()
        guard
            let technology = technologies.first(where: {
                $0.name.caseInsensitiveCompare(requestedName) == .orderedSame
                    || documentationSlug(from: $0.identifier)?.caseInsensitiveCompare(requestedName)
                        == .orderedSame
            })
        else {
            logger.notice("Technology not found", metadata: ["apple_docs.technology": .string(requestedName)])
            throw Error.technologyNotFound(requestedName)
        }

        logger.debug("Resolved technology", metadata: ["apple_docs.technology": .string(technology.name)])
        return ResolvedTechnology(
            name: technology.name,
            documentationSlug: documentationSlug(from: technology.identifier),
            url: publicURL(from: technology.identifier)
        )
    }

    private func documentationSlug(from identifier: String) -> String? {
        let marker = "/documentation/"
        guard let range = identifier.range(of: marker) else {
            logger.trace("Technology identifier has no documentation slug")
            return nil
        }
        let remainder = identifier[range.upperBound...]
        guard !remainder.contains("/") else {
            logger.trace("Ignoring nested documentation slug")
            return nil
        }
        logger.trace("Extracted documentation slug", metadata: ["slug": .string(String(remainder))])
        return String(remainder)
    }

    private func publicURL(from identifier: String) -> String {
        guard identifier.hasPrefix("doc://"), let pathStart = identifier.dropFirst(6).firstIndex(of: "/") else {
            logger.trace("Keeping external technology URL")
            return identifier
        }
        logger.trace("Converted DocC identifier to public URL")
        return "https://developer.apple.com\(identifier[pathStart...].lowercased())"
    }

    private func normalizedSymbolName(_ name: String) -> String {
        logger.trace("Normalizing symbol name for suggestions")
        return name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
