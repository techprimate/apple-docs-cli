import Foundation

enum Dependencies {
    static let httpDataTransport = URLSession.shared
    static let documentationClient = DefaultAppleDocumentationClient(
        dependencies: httpDataTransport
    )

    static func documentationRenderer(
        json: Bool
    ) -> DefaultTypeDocumentationRenderer {
        DefaultTypeDocumentationRenderer(
            output: json ? .json : .text
        )
    }

    static func technologyListRenderer(
        json: Bool
    ) -> DefaultTechnologyListRenderer {
        DefaultTechnologyListRenderer(
            output: json ? .json : .table
        )
    }
}
