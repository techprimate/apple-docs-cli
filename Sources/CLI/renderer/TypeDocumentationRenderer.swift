#if DEBUG
    protocol TypeDocumentationRenderer: Sendable {
        func render(_ document: TypeDocumentationDocument) throws -> String
    }

    extension DefaultTypeDocumentationRenderer: TypeDocumentationRenderer {}
#else
    typealias TypeDocumentationRenderer = DefaultTypeDocumentationRenderer
#endif
