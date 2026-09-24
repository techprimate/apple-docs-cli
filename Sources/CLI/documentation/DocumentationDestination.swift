import Foundation

struct DocumentationDestination: Hashable, Sendable {
    let technology: String
    let path: String
    var fragment: String?

    init(technology: String, path: String, fragment: String? = nil) {
        self.technology = technology
        self.path = path
        self.fragment = fragment
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "developer.apple.com"
        components.path = path
        components.fragment = fragment
        // Internal destinations have already passed boundary validation.
        return components.url!
    }

    static func resolve(
        _ raw: String, relativeTo current: DocumentationDestination
    ) throws -> DocumentationLinkTarget {
        guard !raw.isEmpty, !raw.hasPrefix("//") else { throw DestinationError.invalidURL }
        try validate(raw)
        guard let input = URLComponents(string: raw), input.user == nil, input.password == nil else {
            throw DestinationError.invalidURL
        }
        if input.scheme?.lowercased() == "doc" { return .unavailable(raw) }
        if let scheme = input.scheme, !["https", "http"].contains(scheme.lowercased()) {
            throw DestinationError.invalidURL
        }
        guard let url = URL(string: raw, relativeTo: current.url)?.absoluteURL,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let host = components.host, !host.isEmpty
        else { throw DestinationError.invalidURL }

        guard components.scheme?.lowercased() == "https", host.lowercased() == "developer.apple.com" else {
            return .external(url)
        }
        guard components.port == nil || components.port == 443 else { throw DestinationError.invalidURL }
        let parts = components.path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts[1] == "documentation", !parts[2].isEmpty else {
            return .external(url)
        }
        guard components.query == nil else { throw DestinationError.invalidURL }
        return .documentation(
            DocumentationDestination(
                technology: parts[2].lowercased(), path: components.path, fragment: components.fragment
            ))
    }

    private static func validate(_ raw: String) throws {
        var value = raw
        // Check each decoding layer before URL resolution can erase traversal components.
        while true {
            guard !value.contains("\\"), value.rangeOfCharacter(from: .controlCharacters) == nil,
                let components = URLComponents(string: value),
                !components.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." })
            else { throw DestinationError.invalidURL }
            guard let decoded = value.removingPercentEncoding else { throw DestinationError.invalidURL }
            if decoded == value { return }
            value = decoded
        }
    }

    enum DestinationError: Error {
        case invalidURL
    }
}

enum DocumentationLinkTarget: Equatable, Sendable {
    case documentation(DocumentationDestination)
    case external(URL)
    case unavailable(String)
}
