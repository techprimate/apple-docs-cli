#if DEBUG
    protocol TechnologyListRenderer: Sendable {
        func render(_ technologies: [Technology]) throws -> String
    }

    extension DefaultTechnologyListRenderer: TechnologyListRenderer {}
#else
    typealias TechnologyListRenderer = DefaultTechnologyListRenderer
#endif
