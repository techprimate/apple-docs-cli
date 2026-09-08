import Foundation

#if DEBUG
    protocol AppleDocumentationClient: Sendable {
        func fetchType(named name: String, technology: String) async throws -> TypeDocumentationDocument
    }
#else
    typealias AppleDocumentationClient = DefaultAppleDocumentationClient<URLSession>
#endif

struct DefaultAppleDocumentationClient<Dependencies: DefaultAppleDocumentationClientDependencies>: Sendable {
    enum Error: Swift.Error, Equatable, LocalizedError {
        case httpStatus(Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .httpStatus(let statusCode):
                return "Apple documentation returned HTTP status \(statusCode)."
            case .invalidResponse:
                return "Apple documentation returned an invalid response."
            }
        }
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
        let url = baseURL.appending(component: "documentation")
            .appending(component: technology.lowercased())
            .appending(component: name.lowercased())
            .appendingPathExtension("json")
        let (data, response) = try await dependencies.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw Self.Error.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw Self.Error.httpStatus(httpResponse.statusCode)
        }

        let page = try JSONDecoder().decode(TypeDocumentationPageDTO.self, from: data)
        return TypeDocumentationDocument(data: data, page: page)
    }
}

#if DEBUG
    extension DefaultAppleDocumentationClient: AppleDocumentationClient {}
#endif
