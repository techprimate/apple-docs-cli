import Foundation

struct DefaultTechnologyListRenderer: Sendable {
    enum Output: Sendable {
        case table
        case json
    }

    private let output: Output

    init(output: Output) {
        self.output = output
    }

    func render(_ technologies: [Technology]) throws -> String {
        switch output {
        case .table:
            return renderTable(technologies)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            // JSONEncoder produces valid UTF-8, so preserve a non-optional rendering contract.
            // swiftlint:disable:next optional_data_string_conversion
            return String(decoding: try encoder.encode(technologies), as: UTF8.self)
        }
    }

    private func renderTable(_ technologies: [Technology]) -> String {
        let heading = "TECHNOLOGY"
        let width = max(heading.count, technologies.map(\.name.count).max() ?? 0)
        let rows = technologies.map {
            $0.name + String(repeating: " ", count: width - $0.name.count) + "  " + $0.identifier
        }
        return ([heading + String(repeating: " ", count: width - heading.count) + "  IDENTIFIER"] + rows)
            .joined(separator: "\n")
    }
}
