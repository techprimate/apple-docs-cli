#if DEBUG
    protocol TechnologyListRenderer: Sendable {
        func render(_ technologies: [Technology]) throws -> String
    }

    extension DefaultTechnologyListRenderer: TechnologyListRenderer {}

    protocol TechnologyListRendererProvider {
        associatedtype TechnologyRenderer: TechnologyListRenderer
        func technologyListRenderer(output: OutputOptions) -> TechnologyRenderer
    }

    extension Dependencies: TechnologyListRendererProvider {}
#else
    typealias TechnologyListRenderer = DefaultTechnologyListRenderer
#endif
