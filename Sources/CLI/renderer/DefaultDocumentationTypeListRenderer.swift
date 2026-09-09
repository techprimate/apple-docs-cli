import Foundation

struct DefaultDocumentationTypeListRenderer: Sendable {
    enum Output: Sendable {
        case table
        case json
    }

    private let output: Output

    init(output: Output) {
        self.output = output
    }

    func render(_ types: [DocumentationType]) throws -> String {
        switch output {
        case .table:
            return renderTable(types)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            // JSONEncoder produces valid UTF-8, so preserve a non-optional rendering contract.
            // swiftlint:disable:next optional_data_string_conversion
            return String(decoding: try encoder.encode(types), as: UTF8.self)
        }
    }

    private func renderTable(_ types: [DocumentationType]) -> String {
        let nameWidth = max("SYMBOL".count, types.map(\.name.count).max() ?? 0)
        let kindWidth = max("KIND".count, types.map(\.kind.count).max() ?? 0)
        let pathWidth = max("PATH".count, types.map(\.path.count).max() ?? 0)

        let heading =
            "SYMBOL".padding(toLength: nameWidth, withPad: " ", startingAt: 0) + "  "
            + "KIND".padding(toLength: kindWidth, withPad: " ", startingAt: 0) + "  "
            + "PATH".padding(toLength: pathWidth, withPad: " ", startingAt: 0) + "  URL"
        let rows = types.map { type in
            type.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0) + "  "
                + type.kind.padding(toLength: kindWidth, withPad: " ", startingAt: 0) + "  "
                + type.path.padding(toLength: pathWidth, withPad: " ", startingAt: 0) + "  "
                + type.url
        }
        return ([heading] + rows).joined(separator: "\n")
    }
}
