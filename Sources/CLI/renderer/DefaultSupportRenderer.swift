import Foundation

#if DEBUG
    protocol SupportRenderer: Sendable {
        func render(_ payload: SupportPayload) throws -> String
    }
    extension DefaultSupportRenderer: SupportRenderer {}
#else
    typealias SupportRenderer = DefaultSupportRenderer
#endif

struct DefaultSupportRenderer: Sendable {
    let output: OutputFormat
    let audience: OutputAudience

    func render(_ payload: SupportPayload) throws -> String {
        let presentation = SupportPresenter().present(payload, audience: audience)
        switch output {
        case .json:
            return try StructuredDocumentationRenderer().render(presentation)
        case .text:
            return SupportTextRenderer(agent: audience == .agent).render(presentation)
        }
    }
}
