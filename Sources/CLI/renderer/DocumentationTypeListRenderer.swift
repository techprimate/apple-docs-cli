#if DEBUG
    protocol DocumentationTypeListRenderer: Sendable {
        func render(_ types: [DocumentationType]) throws -> String
    }

    extension DefaultDocumentationTypeListRenderer: DocumentationTypeListRenderer {}
#else
    typealias DocumentationTypeListRenderer = DefaultDocumentationTypeListRenderer
#endif
