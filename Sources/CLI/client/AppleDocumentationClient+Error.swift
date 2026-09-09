import Foundation

extension DefaultAppleDocumentationClient {
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
        case typeSearchNoResults(
            query: String,
            technology: String,
            technologyURL: String
        )
        case unsupportedTechnology(name: String, url: String)

        var isExpected: Bool {
            switch self {
            case .technologyNotFound, .typeNotFound, .typeSearchNoResults, .unsupportedTechnology:
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
            case .typeSearchNoResults(let query, let technology, let technologyURL):
                return """
                    No types matching '\(query)' found in \(technology).

                    Browse available types:
                      apple-docs types list --technology "\(technology)"
                      \(technologyURL)
                    """
            case .unsupportedTechnology(let name, let url):
                return """
                    Type retrieval is unavailable for \(name).

                    Continue in the technology documentation:
                      \(url)
                    """
            }
        }
    }

    struct ResolvedTechnology {
        let name: String
        let documentationSlug: String?
        let url: String
    }
}
