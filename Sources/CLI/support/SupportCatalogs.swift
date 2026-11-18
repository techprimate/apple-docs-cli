import Foundation

struct SupportPageHeader: Encodable, Equatable, Sendable {
    let url: URL
    let title: String
    let introduction: String
}

struct SupportPageLink: Encodable, Equatable, Sendable {
    let title: String
    let url: URL
}

struct SupportDescribedLink: Encodable, Equatable, Sendable {
    let link: SupportPageLink
    let summary: String
}

struct SupportArticlesCatalog: Encodable, Equatable, Sendable {
    let header: SupportPageHeader
    var categories: [SupportArticleCategory]
}

struct SupportArticleCategory: Encodable, Equatable, Sendable {
    let id: String
    let title: String
    let summary: String
    let links: [SupportPageLink]
}

struct SupportHelpCatalog: Encodable, Equatable, Sendable {
    let header: SupportPageHeader
    let featuredResources: [SupportDescribedLink]
    let topicsTitle: String
    let topics: [SupportHelpTopic]
    let glossary: SupportDescribedLink
}

struct SupportHelpTopic: Encodable, Equatable, Sendable {
    let title: String
    let groups: [SupportTopicLinkGroup]
}

struct SupportTopicLinkGroup: Encodable, Equatable, Sendable {
    let title: String?
    let links: [SupportPageLink]
}

struct SupportGlossary: Encodable, Equatable, Sendable {
    let header: SupportPageHeader
    var entries: [SupportGlossaryEntry]
}

struct SupportGlossaryEntry: Encodable, Equatable, Sendable {
    let term: String
    let definition: [SupportContentBlock]
}

struct SupportTermsCatalog: Encodable, Equatable, Sendable {
    let header: SupportPageHeader
    var categories: [SupportTermsCategory]
}

struct SupportTermsCategory: Encodable, Equatable, Sendable {
    let id: String
    let title: String
    let introduction: [SupportContentBlock]
    let entries: [SupportTermsEntry]
}

struct SupportTermsEntry: Encodable, Equatable, Sendable {
    let id: String
    let title: String
    let description: [SupportInline]
    let resources: [SupportTermsResource]
}

struct SupportTermsResource: Encodable, Equatable, Sendable {
    let link: SupportPageLink
    let translations: SupportTranslationSet?
}

struct SupportTranslationSet: Encodable, Equatable, Sendable {
    let notice: [SupportContentBlock]
    let lastUpdatedLabel: String?
    let translations: [SupportPageLink]
}

struct SupportGuideContents: Encodable, Equatable, Sendable {
    let header: SupportPageHeader
    let entries: [SupportContentsEntry]
}

struct SupportContentsEntry: Encodable, Equatable, Sendable {
    let title: String
    let link: SupportPageLink?
    let children: [SupportContentsEntry]
}
