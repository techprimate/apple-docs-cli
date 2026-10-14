#if DEBUG
    protocol DocumentationSearchRenderer: Sendable {
        func render(_ result: DocumentationSearchResult) throws -> String
    }

    extension DefaultDocumentationSearchRenderer: DocumentationSearchRenderer {}

    protocol DocumentationSearchRendererProvider {
        associatedtype SearchRenderer: DocumentationSearchRenderer
        func documentationSearchRenderer(output: OutputOptions) -> SearchRenderer
    }

    extension Dependencies: DocumentationSearchRendererProvider {}
#else
    typealias DocumentationSearchRenderer = DefaultDocumentationSearchRenderer
#endif
