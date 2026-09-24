import Foundation

struct AgentNavigation: Encodable, Equatable, Sendable {
    let technology: String
    let path: String?
    let command: String
}

struct PagePresentation: Encodable, Sendable {
    let document: DocumentationPage
    let audience: OutputAudience
    let navigation: AgentNavigation?
    let relationships: [GroupPresentation]
    let topics: [GroupPresentation]
    let seeAlso: [GroupPresentation]

    private enum CodingKeys: CodingKey {
        case title, kind, technology, path, url, modules, abstract, deprecation, declarations, availability, content
        case relationships, topics, seeAlso, navigation
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(document.title, forKey: .title)
        try container.encode(document.kind, forKey: .kind)
        try container.encode(document.destination.technology, forKey: .technology)
        try container.encode(document.destination.path, forKey: .path)
        try container.encode(document.url, forKey: .url)
        try container.encode(document.modules, forKey: .modules)
        try container.encode(document.abstract, forKey: .abstract)
        try container.encode(document.deprecation, forKey: .deprecation)
        try container.encode(document.declarations, forKey: .declarations)
        try container.encode(document.availability, forKey: .availability)
        try container.encode(document.content, forKey: .content)
        try container.encode(relationships, forKey: .relationships)
        try container.encode(topics, forKey: .topics)
        try container.encode(seeAlso, forKey: .seeAlso)
        try container.encodeIfPresent(navigation, forKey: .navigation)
    }
}

struct GroupPresentation: Encodable, Sendable {
    let id: String
    let title: String
    let references: [ReferencePresentation]
}

struct ReferencePresentation: Encodable, Sendable {
    let reference: DocumentationReference
    let navigation: AgentNavigation?

    private enum CodingKeys: CodingKey {
        case id, title, kind, abstract, target, navigation
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(reference.id, forKey: .id)
        try container.encode(reference.title, forKey: .title)
        try container.encode(reference.kind, forKey: .kind)
        try container.encode(reference.abstract, forKey: .abstract)
        try container.encode(PresentedLinkTarget(target: reference.target), forKey: .target)
        try container.encodeIfPresent(navigation, forKey: .navigation)
    }
}

struct SymbolPresentation: Encodable, Sendable {
    let name: String
    let kind: String
    let path: String
    let url: String
    let navigation: AgentNavigation?
}

struct TechnologyPresentation: Encodable, Sendable {
    let name: String
    let identifier: String
    let navigation: AgentNavigation?
}

private struct PresentedLinkTarget: Encodable {
    let target: DocumentationLinkTarget

    private enum CodingKeys: CodingKey {
        case type, technology, path, fragment, url, label
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch target {
        case .documentation(let destination):
            try container.encode("documentation", forKey: .type)
            try container.encode(destination.technology, forKey: .technology)
            try container.encode(destination.path, forKey: .path)
            try container.encodeIfPresent(destination.fragment, forKey: .fragment)
            try container.encode(destination.url, forKey: .url)
        case .external(let url):
            try container.encode("external", forKey: .type)
            try container.encode(url, forKey: .url)
        case .unavailable(let label):
            try container.encode("unavailable", forKey: .type)
            try container.encode(label, forKey: .label)
        }
    }
}

extension DocumentationInline: Encodable {
    private enum CodingKeys: CodingKey {
        case type, text, target
    }

    var text: String {
        switch self {
        case .text(let text), .code(let text): return text
        case .link(let label, _): return label.map(\.text).joined()
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        switch self {
        case .text: try container.encode("text", forKey: .type)
        case .code: try container.encode("code", forKey: .type)
        case .link(_, let target):
            try container.encode("link", forKey: .type)
            try container.encode(PresentedLinkTarget(target: target), forKey: .target)
        }
    }
}

extension DocumentationBlock: Encodable {
    private enum CodingKeys: CodingKey {
        case type, inlineContent, text, code, syntax, items, startIndex, content, style, name
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paragraph(let content):
            try container.encode("paragraph", forKey: .type)
            try container.encode(content, forKey: .inlineContent)
        case .heading(let text):
            try container.encode("heading", forKey: .type)
            try container.encode(text, forKey: .text)
        case .codeListing(let code, let syntax):
            try container.encode("codeListing", forKey: .type)
            try container.encode(code, forKey: .code)
            try container.encodeIfPresent(syntax, forKey: .syntax)
        case .orderedList(let items, let start):
            try container.encode("orderedList", forKey: .type)
            try container.encode(items, forKey: .items)
            try container.encode(start, forKey: .startIndex)
        case .unorderedList(let items):
            try container.encode("unorderedList", forKey: .type)
            try container.encode(items, forKey: .items)
        case .aside(let content, let style, let name):
            try container.encode("aside", forKey: .type)
            try container.encode(content, forKey: .content)
            try container.encode(style, forKey: .style)
            try container.encodeIfPresent(name, forKey: .name)
        }
    }
}
