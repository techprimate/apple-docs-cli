import Foundation

struct DefaultTechnologyListRenderer: Sendable {
    enum Output: Sendable {
        case table
        case json
    }

    private let output: Output
    private let audience: OutputAudience

    init(output: Output, audience: OutputAudience = .human) {
        self.output = output
        self.audience = audience
    }

    func render(_ technologies: [Technology]) throws -> String {
        switch output {
        case .table:
            if audience == .agent {
                let presentation = DocumentationPresenter().technologies(technologies, audience: .agent)
                return AgentDocumentationRenderer().render(presentation)
            }
            return terminalSafeText(renderTable(technologies))
        case .json:
            let presentation = DocumentationPresenter().technologies(technologies, audience: audience)
            return try StructuredDocumentationRenderer().render(presentation)
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
