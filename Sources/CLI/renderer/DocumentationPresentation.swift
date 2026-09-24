struct AgentNavigation: Equatable, Sendable {
    let technology: String
    let path: String?
    let command: String
}

struct PagePresentation: Sendable {
    let document: DocumentationPage
    let audience: OutputAudience
    let navigation: AgentNavigation?
    let relationships: [GroupPresentation]
    let topics: [GroupPresentation]
    let seeAlso: [GroupPresentation]
}

struct GroupPresentation: Sendable {
    let id: String
    let title: String
    let references: [ReferencePresentation]
}

struct ReferencePresentation: Sendable {
    let reference: DocumentationReference
    let navigation: AgentNavigation?
}

struct SymbolPresentation: Sendable {
    let name: String
    let kind: String
    let path: String
    let url: String
    let navigation: AgentNavigation?
}

struct TechnologyPresentation: Sendable {
    let name: String
    let identifier: String
    let navigation: AgentNavigation?
}
