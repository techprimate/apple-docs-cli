import Foundation

#if DEBUG
    protocol AppleDocumentationClient: Sendable {
        func fetchType(named name: String, technology: String) async throws -> TypeDocumentationDocument
    }
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

    private let dependencies: Dependencies
    private let baseURL: URL

    init(
        dependencies: Dependencies,
        baseURL: URL = defaultBaseURL
    ) {
        self.dependencies = dependencies
        self.baseURL = baseURL
    }

    func fetchType(
        named name: String,
        technology: String
    ) async throws -> TypeDocumentationDocument {
        do {
            return TypeDocumentationDocument(
                data: try await fetchData(from: typeURL(name: name, technology: technology))
            )
        } catch Error.httpStatus(404) {
            let resolved = try await resolveTechnology(named: technology)
            guard let slug = resolved.documentationSlug else {
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }

            // Display names do not always match DocC path components, such as Apple CryptoKit.
            if slug.caseInsensitiveCompare(technology) != .orderedSame {
                do {
                    return TypeDocumentationDocument(
                        data: try await fetchData(from: typeURL(name: name, technology: slug))
                    )
                } catch Error.httpStatus(404) {
                    // Continue with the canonical root so the error can offer useful discovery links.
                }
            }

            let types = try await fetchTypesDirect(technology: slug)
            let normalizedName = normalizedSymbolName(name)
            let suggestion = types.first {
                normalizedSymbolName($0.name) == normalizedName
            }
            throw Error.typeNotFound(
                name: name,
                technology: resolved.name,
                suggestion: suggestion,
                technologyURL: resolved.url
            )
        }
    }

    func fetchTypes(technology: String) async throws -> [DocumentationType] {
        do {
            return try await fetchTypesDirect(technology: technology)
        } catch Error.httpStatus(404) {
            let resolved = try await resolveTechnology(named: technology)
            guard let slug = resolved.documentationSlug else {
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
            guard slug.caseInsensitiveCompare(technology) != .orderedSame else {
                // Retrying the same case-insensitive path cannot produce a different result.
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
            do {
                return try await fetchTypesDirect(technology: slug)
            } catch Error.httpStatus(404) {
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
        }
    }

    func fetchTechnologies() async throws -> [Technology] {
        let url = baseURL.appending(component: "documentation")
            .appending(component: "technologies")
            .appendingPathExtension("json")
        let data = try await fetchData(from: url)
        let page = try JSONDecoder().decode(TechnologyCatalogPageDTO.self, from: data)
        return page.sections.flatMap(\.groups).flatMap(\.technologies).map {
            Technology(name: $0.title, identifier: $0.destination.identifier)
        }
    }

    private func fetchTypesDirect(technology: String) async throws -> [DocumentationType] {
        let path = "/documentation/\(technology.lowercased())"
        let page = try await fetchDocumentationPage(path: path)
        return sortTypes(documentationTypes(in: page, technology: technology))
    }

    func fetchDocumentationPage(path: String) async throws -> TechnologyDocumentationPageDTO {
        var url = baseURL
        for component in path.split(separator: "/") {
            url.append(component: component)
        }
        url.appendPathExtension("json")
        let data = try await fetchData(from: url)
        return try JSONDecoder().decode(TechnologyDocumentationPageDTO.self, from: data)
    }

    func documentationTypes(
        in page: TechnologyDocumentationPageDTO,
        technology: String
    ) -> [DocumentationType] {
        let pathPrefix = "/documentation/\(technology.lowercased())/"

        // Pages may reference articles and neighboring frameworks. Role and path filtering keeps
        // search results scoped to APIs in the requested technology.
        return page.references.values.compactMap { reference in
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
    }

    func sortTypes<S: Sequence>(_ types: S) -> [DocumentationType]
    where S.Element == DocumentationType {
        types.sorted {
            let comparison = $0.name.compare($1.name, options: .caseInsensitive)
            return comparison == .orderedSame ? $0.path < $1.path : comparison == .orderedAscending
        }
    }

    private func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await dependencies.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
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
        return url
    }

    func resolveTechnology(named requestedName: String) async throws -> ResolvedTechnology {
        let technologies = try await fetchTechnologies()
        guard
            let technology = technologies.first(where: {
                $0.name.caseInsensitiveCompare(requestedName) == .orderedSame
                    || documentationSlug(from: $0.identifier)?.caseInsensitiveCompare(requestedName)
                        == .orderedSame
            })
        else {
            throw Error.technologyNotFound(requestedName)
        }

        return ResolvedTechnology(
            name: technology.name,
            documentationSlug: documentationSlug(from: technology.identifier),
            url: publicURL(from: technology.identifier)
        )
    }

    private func documentationSlug(from identifier: String) -> String? {
        let marker = "/documentation/"
        guard let range = identifier.range(of: marker) else {
            return nil
        }
        let remainder = identifier[range.upperBound...]
        guard !remainder.contains("/") else {
            return nil
        }
        return String(remainder)
    }

    private func publicURL(from identifier: String) -> String {
        guard identifier.hasPrefix("doc://"), let pathStart = identifier.dropFirst(6).firstIndex(of: "/") else {
            return identifier
        }
        return "https://developer.apple.com\(identifier[pathStart...].lowercased())"
    }

    private func normalizedSymbolName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

#if DEBUG
    extension DefaultAppleDocumentationClient: AppleDocumentationClient {}
#endif
