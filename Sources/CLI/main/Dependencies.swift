import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

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

    static func documentationTypeListRenderer(
        json: Bool
    ) -> DefaultDocumentationTypeListRenderer {
        DefaultDocumentationTypeListRenderer(
            output: json ? .json : .table
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
