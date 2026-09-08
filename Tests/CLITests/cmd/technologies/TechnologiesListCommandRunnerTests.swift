import Foundation
import Testing

@testable import CLI

@Suite("Technologies list command runner")
struct TechnologiesListCommandRunnerTests {
    @Test("sorts technologies case-insensitively before rendering")
    func sortsTechnologies() async throws {
        // -- Arrange --
        let client = UnsortedTechnologyCatalogClient(
            technologies: [
                Technology(name: "swiftUI", identifier: "swiftui"),
                Technology(name: "MetricKit", identifier: "metrickit"),
                Technology(name: "ARKit", identifier: "arkit"),
            ]
        )
        let runner = TechnologiesListCommandRunner(
            client: client,
            renderer: DefaultTechnologyListRenderer(output: .json)
        )

        // -- Act --
        let output = try await runner.run()

        // -- Assert --
        let technologies = try JSONDecoder().decode([Technology].self, from: Data(output.utf8))
        #expect(technologies.map(\.name) == ["ARKit", "MetricKit", "swiftUI"])
    }
}

private struct UnsortedTechnologyCatalogClient: TechnologyCatalogClient {
    let technologies: [Technology]

    func fetchTechnologies() async throws -> [Technology] {
        technologies
    }
}
