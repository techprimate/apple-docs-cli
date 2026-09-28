#if DEBUG
    protocol TypeDocumentationRenderer: Sendable {
        func render(_ document: TypeDocumentationDocument) throws -> String
    }

    extension DefaultTypeDocumentationRenderer: TypeDocumentationRenderer {}

    protocol TypeDocumentationRendererProvider {
        associatedtype TypeRenderer: TypeDocumentationRenderer
        func documentationRenderer(output: OutputOptions) -> TypeRenderer
    }

    extension Dependencies: TypeDocumentationRendererProvider {}
#else
    typealias TypeDocumentationRenderer = DefaultTypeDocumentationRenderer
#endif
