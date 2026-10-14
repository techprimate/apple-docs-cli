import Foundation
import Logging

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct LoadedDocumentationPage: Sendable {
    let page: DocumentationPage
    let responseByteCount: Int
}

#if DEBUG
    protocol AppleDocumentationRepository: Sendable {
        func fetchPage(named name: String, technology: String) async throws -> LoadedDocumentationPage
    }
    extension DefaultAppleDocumentationRepository: AppleDocumentationRepository {}

    protocol AppleDocumentationRepositoryProvider {
        associatedtype Repository: AppleDocumentationRepository
        var documentationRepository: Repository { get }
    }
    extension Dependencies: AppleDocumentationRepositoryProvider {}
    typealias DefaultAppleDocumentationRepositoryDependencies = AppleDocumentationClient
#else
    typealias AppleDocumentationRepository = DefaultAppleDocumentationRepository<
        DefaultAppleDocumentationClient<URLSession>
    >
    typealias DefaultAppleDocumentationRepositoryDependencies = DefaultAppleDocumentationClient<URLSession>
#endif

struct DefaultAppleDocumentationRepository<Dependencies: DefaultAppleDocumentationRepositoryDependencies>: Sendable {
    let logger: Logger
    private let dependencies: Dependencies

    init(logger: Logger, dependencies: Dependencies) {
        self.logger = logger
        self.dependencies = dependencies
    }

    func fetchPage(named name: String, technology: String) async throws -> LoadedDocumentationPage {
        try decodePage(try await fetchType(named: name, technology: technology))
    }

    func fetchPage(at destination: DocumentationDestination) async throws -> LoadedDocumentationPage {
        try decodePage(try await fetchDocument(at: destination))
    }

    private func decodePage(_ document: TypeDocumentationDocument) throws -> LoadedDocumentationPage {
        LoadedDocumentationPage(
            page: try DocumentationPageDecoder().decode(document.data, destination: document.destination),
            responseByteCount: document.data.count)
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
            let document = try await fetchDocument(at: typeDestination(name: name, technology: technology))
            logger.info("Fetched type documentation", metadata: metadata)
            return document
        } catch AppleDocumentationClientError.httpStatus(404) {
            logger.debug("Type path not found, resolving technology", metadata: metadata)
            let resolved = try await resolveTechnology(named: technology)
            guard let slug = resolved.documentationSlug else {
                logger.notice("Technology has no documentation root", metadata: metadata)
                throw AppleDocumentationRepositoryError.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }

            // Display names do not always match DocC path components, such as Apple CryptoKit.
            if slug.caseInsensitiveCompare(technology) != .orderedSame {
                logger.debug("Retrying type with canonical technology", metadata: ["slug": .string(slug)])
                do {
                    let document = try await fetchDocument(at: typeDestination(name: name, technology: slug))
                    logger.info("Fetched type documentation", metadata: metadata)
                    return document
                } catch AppleDocumentationClientError.httpStatus(404) {
                    logger.debug("Canonical type path not found, looking for suggestions", metadata: metadata)
                }
            }

            let types = try await fetchTypesDirect(technology: slug)
            let normalizedName = normalizedSymbolName(name)
            let suggestion = types.first {
                normalizedSymbolName($0.name) == normalizedName
            }
            logger.notice("Type not found", metadata: ["suggestion_found": .stringConvertible(suggestion != nil)])
            throw AppleDocumentationRepositoryError.typeNotFound(
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
        let page = try await dependencies.fetchTechnologyCatalog()
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

    func fetchDocument(at destination: DocumentationDestination) async throws -> TypeDocumentationDocument {
        try await dependencies.fetchDocument(at: destination)
    }

    func fetchRootDocument(technology: String) async throws -> TypeDocumentationDocument {
        try await fetchDocumentationRoot(technology: technology).document
    }

    func fetchDocumentationPage(path: String) async throws -> TechnologyDocumentationPageDTO {
        try decodeDiscoveryPage(
            try await dependencies.fetchDocument(
                at: DocumentationDestination(
                    technology: String(path.split(separator: "/").dropFirst().first ?? ""), path: path)
            ).data,
            path: path)
    }

    private func decodeDiscoveryPage(_ data: Data, path: String) throws -> TechnologyDocumentationPageDTO {
        do {
            let page = try JSONDecoder().decode(TechnologyDocumentationPageDTO.self, from: data)
            logger.trace(
                "Decoded documentation page", metadata: ["references": .stringConvertible(page.references.count)])
            return page
        } catch {
            logger.error("Failed to decode documentation page", metadata: ["path": .string(path)])
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

extension DefaultAppleDocumentationRepository {
    struct DocumentationRoot: Sendable {
        let page: TechnologyDocumentationPageDTO
        let document: TypeDocumentationDocument
        let slug: String
        let name: String
        let url: String
    }

    func fetchDocumentationRoot(technology: String) async throws -> DocumentationRoot {
        do {
            return try await loadRoot(
                slug: technology, name: technology,
                url: "https://developer.apple.com/documentation/\(technology.lowercased())"
            )
        } catch AppleDocumentationClientError.httpStatus(404) {
            logger.debug("Documentation root not found, resolving technology")
            let resolved = try await resolveTechnology(named: technology)
            guard let slug = resolved.documentationSlug else {
                logger.notice("Technology has no documentation root")
                throw AppleDocumentationRepositoryError.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
            guard slug.caseInsensitiveCompare(technology) != .orderedSame else {
                // Retrying the same case-insensitive path cannot produce a different result.
                logger.notice("Documentation root unavailable, skipping identical retry")
                throw AppleDocumentationRepositoryError.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
            logger.debug("Retrying documentation root with canonical technology", metadata: ["slug": .string(slug)])
            do {
                return try await loadRoot(slug: slug, name: resolved.name, url: resolved.url)
            } catch AppleDocumentationClientError.httpStatus(404) {
                logger.notice("Canonical documentation root unavailable", metadata: ["slug": .string(slug)])
                throw AppleDocumentationRepositoryError.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
        }
    }

    private func loadRoot(slug: String, name: String, url: String) async throws -> DocumentationRoot {
        let destination = DocumentationDestination(
            technology: slug.lowercased(), path: "/documentation/\(slug.lowercased())"
        )
        let document = try await fetchDocument(at: destination)
        return DocumentationRoot(
            page: try decodeDiscoveryPage(document.data, path: destination.path), document: document,
            slug: slug, name: name, url: url
        )
    }

    private func typeDestination(name: String, technology: String) -> DocumentationDestination {
        // Slash-separated DocC paths may contain dots in disambiguation suffixes.
        let pathName = name.contains("/") ? name : name.replacingOccurrences(of: ".", with: "/")
        let components = pathName.split(separator: "/")
        let path = "/documentation/\(technology.lowercased())/" + components.joined(separator: "/").lowercased()
        return DocumentationDestination(technology: technology.lowercased(), path: path)
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
            throw AppleDocumentationRepositoryError.technologyNotFound(requestedName)
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
