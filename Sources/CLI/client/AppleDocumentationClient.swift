import Foundation

#if DEBUG
    protocol AppleDocumentationClient: Sendable {
        func fetchType(named name: String, technology: String) async throws -> TypeDocumentationDocument
    }
#else
    typealias AppleDocumentationClient = DefaultAppleDocumentationClient<URLSession>
#endif

struct DefaultAppleDocumentationClient<Dependencies: DefaultAppleDocumentationClientDependencies>: Sendable {
    enum Error: Swift.Error, Equatable, LocalizedError, ExpectedCommandError {
        case httpStatus(Int)
        case invalidResponse
        case technologyNotFound(String)
        case typeNotFound(
            name: String,
            technology: String,
            suggestion: DocumentationType?,
            technologyURL: String
        )
        case unsupportedTechnology(name: String, url: String)

        var isExpected: Bool {
            switch self {
            case .technologyNotFound, .typeNotFound, .unsupportedTechnology:
                return true
            case .httpStatus, .invalidResponse:
                return false
            }
        }

        var errorDescription: String? {
            switch self {
            case .httpStatus(let statusCode):
                return "Apple documentation returned HTTP status \(statusCode)."
            case .invalidResponse:
                return "Apple documentation returned an invalid response."
            case .technologyNotFound(let technology):
                return """
                    Apple documentation technology '\(technology)' was not found.

                    Browse available technologies:
                      apple-docs technologies list
                    """
            case .typeNotFound(let name, let technology, let suggestion, let technologyURL):
                var sections = ["No Apple documentation found for '\(name)' in \(technology)."]
                if let suggestion {
                    sections.append(
                        """
                        Did you mean:
                          \(suggestion.name)
                          \(suggestion.url)
                        """
                    )
                }
                sections.append(
                    """
                    Browse available types:
                      apple-docs types list --technology "\(technology)"
                      \(technologyURL)
                    """
                )
                return sections.joined(separator: "\n\n")
            case .unsupportedTechnology(let name, let url):
                return """
                    Type retrieval is unavailable for \(name).

                    Continue in the technology documentation:
                      \(url)
                    """
            }
        }
    }

    private struct ResolvedTechnology {
        let name: String
        let documentationSlug: String?
        let url: String
    }

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
                throw Error.unsupportedTechnology(name: resolved.name, url: resolved.url)
            }
            return try await fetchTypesDirect(technology: slug)
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
        let url = baseURL.appending(component: "documentation")
            .appending(component: technology.lowercased())
            .appendingPathExtension("json")
        let data = try await fetchData(from: url)
        let page = try JSONDecoder().decode(TechnologyDocumentationPageDTO.self, from: data)
        let pathPrefix = "/documentation/\(technology.lowercased())/"

        // Root pages also reference articles and neighboring frameworks. The symbol role and path
        // prefix keep this command faithful to Apple's direct API listing for the requested technology.
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
        }.sorted {
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

    private func resolveTechnology(named requestedName: String) async throws -> ResolvedTechnology {
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
