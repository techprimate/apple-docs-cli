#if DEBUG
    protocol DocumentationTypeListRenderer: Sendable {
        func render(_ types: [DocumentationType]) throws -> String
    }

    extension DefaultDocumentationTypeListRenderer: DocumentationTypeListRenderer {}

    protocol DocumentationTypeListRendererProvider {
        associatedtype Renderer: DocumentationTypeListRenderer
        func documentationTypeListRenderer(output: OutputOptions, technology: String) -> Renderer
    }

    extension Dependencies: DocumentationTypeListRendererProvider {}
#else
    typealias DocumentationTypeListRenderer = DefaultDocumentationTypeListRenderer
#endif
