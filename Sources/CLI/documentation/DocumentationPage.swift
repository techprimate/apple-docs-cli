import Foundation

struct DocumentationPage: Equatable, Sendable {
    let destination: DocumentationDestination
    let title: String
    let kind: String
    var symbolKind: String?
    var roleHeading: String?
    var modules: [String] = []
    var abstract: [DocumentationInline] = []
    var deprecation: [DocumentationBlock] = []
    var declarations: [DocumentationDeclaration] = []
    var availability: [DocumentationAvailability] = []
    var content: [DocumentationBlock] = []
    var relationships: [DocumentationGroup] = []
    var topics: [DocumentationGroup] = []
    var seeAlso: [DocumentationGroup] = []

    var url: URL { destination.url }
}

indirect enum DocumentationInline: Equatable, Sendable {
    case text(String)
    case code(String)
    case link(label: [DocumentationInline], target: DocumentationLinkTarget)
}

indirect enum DocumentationBlock: Equatable, Sendable {
    case paragraph([DocumentationInline])
    case heading(String)
    case codeListing(code: [String], syntax: String?)
    case orderedList(items: [[DocumentationBlock]], startIndex: Int)
    case unorderedList([[DocumentationBlock]])
    case aside(content: [DocumentationBlock], style: String, name: String?)
}

struct DocumentationDeclaration: Encodable, Equatable, Sendable {
    let languages: [String]
    let text: String
}

struct DocumentationAvailability: Encodable, Equatable, Sendable {
    let name: String
    let introducedAt: String?
    let deprecatedAt: String?
    var obsoletedAt: String?
    var isBeta = false
    var isUnavailable = false
}

struct DocumentationReference: Equatable, Sendable {
    let id: String
    let title: String
    let kind: String
    var abstract: [DocumentationInline] = []
    let target: DocumentationLinkTarget
}

struct DocumentationGroup: Equatable, Sendable {
    let id: String
    let title: String
    let references: [DocumentationReference]
}
