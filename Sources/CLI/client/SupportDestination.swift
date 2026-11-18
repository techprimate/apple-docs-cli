import Foundation

struct SupportDestination: Equatable, Hashable, Sendable {
    let path: String

    init(path raw: String) throws {
        var value = raw
        while true {
            guard !value.hasPrefix("//"), !value.contains("\\"), !value.contains("//"),
                value.rangeOfCharacter(from: .controlCharacters) == nil,
                let components = URLComponents(string: value),
                components.scheme == nil, components.host == nil,
                components.query == nil, components.fragment == nil,
                !components.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." })
            else { throw AppleSupportClientError.invalidPath }
            guard let decoded = value.removingPercentEncoding else { throw AppleSupportClientError.invalidPath }
            if decoded == value { break }
            value = decoded
        }
        let path = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let root = path.split(separator: "/").first,
            root == "help" || root == "support" || path == "xcode/system-requirements"
        else {
            throw AppleSupportClientError.invalidPath
        }
        self.path = path
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "developer.apple.com"
        components.path = "/" + path + (path.lowercased().hasSuffix(".pdf") ? "" : "/")
        return components.url!
    }

    init(responseURL url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            components.scheme == "https", components.host?.lowercased() == "developer.apple.com",
            components.port == nil || components.port == 443,
            components.user == nil, components.password == nil,
            components.query == nil, components.fragment == nil
        else { throw AppleSupportClientError.invalidResponse }
        do {
            try self.init(path: components.percentEncodedPath)
        } catch {
            throw AppleSupportClientError.invalidResponse
        }
    }
}
