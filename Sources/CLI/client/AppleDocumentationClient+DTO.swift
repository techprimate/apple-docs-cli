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
    let text: String?
}

struct DocumentationBlockDTO: Decodable, Sendable {
    let inlineContent: [DocumentationTextDTO]?
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
}

struct DocumentationModule: Decodable, Sendable {
    let name: String
}

struct DocumentationPlatform: Decodable, Sendable {
    let deprecatedAt: String?
    let introducedAt: String?
    let name: String
}
