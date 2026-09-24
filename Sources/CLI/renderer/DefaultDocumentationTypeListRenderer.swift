import Foundation

struct DefaultDocumentationTypeListRenderer: Sendable {
    enum Output: Sendable {
        case table
        case json
    }

    private let output: Output
    private let audience: OutputAudience
    private let technology: String

    init(output: Output, audience: OutputAudience = .human, technology: String = "") {
        self.output = output
        self.audience = audience
        self.technology = technology
    }

    func render(_ types: [DocumentationType]) throws -> String {
        switch output {
        case .table:
            if audience == .agent {
                let presentation = DocumentationPresenter().symbols(types, technology: technology, audience: .agent)
                return AgentDocumentationRenderer().render(presentation, technology: technology)
            }
            return terminalSafeText(renderTable(types))
        case .json:
            let presentation = DocumentationPresenter().symbols(types, technology: technology, audience: audience)
            return try StructuredDocumentationRenderer().render(presentation)
        }
    }

    private func renderTable(_ types: [DocumentationType]) -> String {
        guard !types.isEmpty else { return "No symbols found." }
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
