import Foundation
import Testing

@testable import CLI

@Suite("Default technology list renderer")
struct DefaultTechnologyListRendererTests {
    @Test("renders an aligned two-column table")
    func rendersTable() throws {
        // -- Arrange --
        let technologies = [
            Technology(
                name: "MetricKit",
                identifier: "doc://com.apple.documentation/documentation/MetricKit"
            ),
            Technology(
                name: "Human Interface Guidelines",
                identifier: "doc://com.apple.documentation/design/human-interface-guidelines"
            ),
        ]
        let renderer = DefaultTechnologyListRenderer(output: .table)

        // -- Act --
        let output = try renderer.render(technologies)

        // -- Assert --
        #expect(
            output == """
                TECHNOLOGY                  IDENTIFIER
                MetricKit                   doc://com.apple.documentation/documentation/MetricKit
                Human Interface Guidelines  doc://com.apple.documentation/design/human-interface-guidelines
                """
        )
    }

    @Test("aligns table columns after removing remote control characters")
    func alignsSanitizedTable() throws {
        // -- Arrange --
        let technologies = [
            Technology(
                name: "MetricKit\u{0007}", identifier: "doc://com.apple.documentation/documentation/MetricKit\u{0007}"),
            Technology(name: "Swift", identifier: "doc://com.apple.documentation/documentation/Swift"),
        ]
        let renderer = DefaultTechnologyListRenderer(output: .table)

        // -- Act --
        let output = try renderer.render(technologies)

        // -- Assert --
        #expect(
            output == """
                TECHNOLOGY  IDENTIFIER
                MetricKit   doc://com.apple.documentation/documentation/MetricKit
                Swift       doc://com.apple.documentation/documentation/Swift
                """
        )
    }

    @Test("renders table headers for an empty catalog")
    func rendersEmptyTable() throws {
        // -- Arrange --
        let renderer = DefaultTechnologyListRenderer(output: .table)

        // -- Act --
        let output = try renderer.render([])

        // -- Assert --
        #expect(output == "TECHNOLOGY  IDENTIFIER")
    }

    @Test("renders a JSON array of technology objects")
    func rendersJSON() throws {
        // -- Arrange --
        let technologies = [
            Technology(
                name: "CareKit",
                identifier: "https://carekit-apple.github.io/CareKit/documentation/carekit"
            ),
            Technology(
                name: "MetricKit",
                identifier: "doc://com.apple.documentation/documentation/MetricKit"
            ),
        ]
        let renderer = DefaultTechnologyListRenderer(output: .json)

        // -- Act --
        let output = try renderer.render(technologies)

        // -- Assert --
        let decoded = try JSONDecoder().decode([Technology].self, from: Data(output.utf8))
        #expect(decoded == technologies)
    }
}
