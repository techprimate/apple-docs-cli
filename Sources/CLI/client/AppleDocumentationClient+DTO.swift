struct TypeDocumentationPageDTO: Decodable, Sendable {
    let abstract: [DocumentationTextDTO]
    let deprecationSummary: [DocumentationBlockDTO]?
    let metadata: DocumentationMetadataDTO
    let primaryContentSections: [DocumentationContentSectionDTO]
    let references: [String: DocumentationReferenceDTO]
    let relationshipsSections: [DocumentationReferenceSectionDTO]?
    let seeAlsoSections: [DocumentationReferenceSectionDTO]?
    let topicSections: [DocumentationReferenceSectionDTO]?
    let variants: [DocumentationVariantDTO]?
}

struct DocumentationVariantDTO: Decodable, Sendable {
    let paths: [String]
}

struct DocumentationTextDTO: Decodable, Sendable {
    let code: String?
    let identifier: String?
    let inlineContent: [DocumentationTextDTO]?
    let text: String?
}

enum DocumentationBlockDTO: Decodable, Sendable {
    case paragraph([DocumentationTextDTO])
    case heading(String)
    case codeListing(code: [String], syntax: String?)
    case orderedList(items: [DocumentationListItemDTO], startIndex: Int)
    case unorderedList([DocumentationListItemDTO])
    case aside(content: [DocumentationBlockDTO], style: String, name: String?)
    case unsupported

    private enum CodingKeys: CodingKey {
        case code, content, inlineContent, items, name, startIndex, style, syntax, text, type
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "paragraph":
            self = .paragraph(try container.decode([DocumentationTextDTO].self, forKey: .inlineContent))
        case "heading":
            self = .heading(try container.decode(String.self, forKey: .text))
        case "codeListing":
            self = .codeListing(
                code: try container.decode([String].self, forKey: .code),
                syntax: try container.decodeIfPresent(String.self, forKey: .syntax)
            )
        case "orderedList":
            self = .orderedList(
                items: try container.decode([DocumentationListItemDTO].self, forKey: .items),
                startIndex: try container.decodeIfPresent(Int.self, forKey: .startIndex) ?? 1
            )
        case "unorderedList":
            self = .unorderedList(try container.decode([DocumentationListItemDTO].self, forKey: .items))
        case "aside":
            self = .aside(
                content: try container.decode([DocumentationBlockDTO].self, forKey: .content),
                style: try container.decode(String.self, forKey: .style),
                name: try container.decodeIfPresent(String.self, forKey: .name)
            )
        default:
            self = .unsupported
        }
    }
}

struct DocumentationListItemDTO: Decodable, Sendable {
    let content: [DocumentationBlockDTO]
}

struct DocumentationReferenceDTO: Decodable, Sendable {
    let abstract: [DocumentationTextDTO]?
    let fragments: [DocumentationFragmentDTO]?
    let kind: String?
    let role: String?
    let title: String?
    let url: String?
}

struct DocumentationFragmentDTO: Decodable, Sendable {
    let kind: String
    let text: String
}

struct TechnologyDocumentationPageDTO: Decodable, Sendable {
    let references: [String: DocumentationReferenceDTO]
}

struct DocumentationReferenceSectionDTO: Decodable, Sendable {
    let identifiers: [String]
    let title: String
}

struct DocumentationContentSectionDTO: Decodable, Sendable {
    let content: [DocumentationBlockDTO]?
    let declarations: [DocumentationDeclarationDTO]?
    let kind: String
}

struct DocumentationDeclarationDTO: Decodable, Sendable {
    let languages: [String]
    let tokens: [DocumentationTokenDTO]
}

struct DocumentationTokenDTO: Decodable, Sendable {
    let text: String
}

struct DocumentationMetadataDTO: Decodable, Sendable {
    let modules: [DocumentationModule]
    let platforms: [DocumentationPlatform]
    let roleHeading: String
    let symbolKind: String
    let title: String

    private enum CodingKeys: CodingKey {
        case modules
        case platforms
        case roleHeading
        case symbolKind
        case title
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modules = try container.decode([DocumentationModule].self, forKey: .modules)
        platforms = try container.decodeIfPresent([DocumentationPlatform].self, forKey: .platforms) ?? []
        roleHeading = try container.decode(String.self, forKey: .roleHeading)
        symbolKind = try container.decode(String.self, forKey: .symbolKind)
        title = try container.decode(String.self, forKey: .title)
    }
}

struct DocumentationModule: Decodable, Sendable {
    let name: String
}

struct DocumentationPlatform: Decodable, Sendable {
    let deprecatedAt: String?
    let introducedAt: String?
    let name: String
}
