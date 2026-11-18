import Foundation

struct SupportPageHeader: Equatable, Sendable {
    let url: URL
    let title: String
    let introduction: String
}

struct SupportPageLink: Equatable, Sendable {
    let title: String
    let url: URL
}

struct SupportDescribedLink: Equatable, Sendable {
    let link: SupportPageLink
    let summary: String
}

struct SupportArticlesCatalog: Equatable, Sendable {
    let header: SupportPageHeader
    var categories: [SupportArticleCategory]
}

struct SupportArticleCategory: Equatable, Sendable {
    let id: String
    let title: String
    let summary: String
    let links: [SupportPageLink]
}

struct SupportHelpCatalog: Equatable, Sendable {
    let header: SupportPageHeader
    let featuredResources: [SupportDescribedLink]
    let topicsTitle: String
    let topics: [SupportHelpTopic]
    let glossary: SupportDescribedLink
}

struct SupportHelpTopic: Equatable, Sendable {
    let title: String
    let groups: [SupportTopicLinkGroup]
}

struct SupportTopicLinkGroup: Equatable, Sendable {
    let title: String?
    let links: [SupportPageLink]
}

struct SupportGlossary: Equatable, Sendable {
    let header: SupportPageHeader
    var entries: [SupportGlossaryEntry]
}

struct SupportGlossaryEntry: Equatable, Sendable {
    let term: String
    let definition: [SupportContentBlock]
}

struct SupportTermsCatalog: Equatable, Sendable {
    let header: SupportPageHeader
    var categories: [SupportTermsCategory]
}

struct SupportTermsCategory: Equatable, Sendable {
    let id: String
    let title: String
    let introduction: [SupportContentBlock]
    let entries: [SupportTermsEntry]
}

struct SupportTermsEntry: Equatable, Sendable {
    let id: String
    let title: String
    let description: [SupportInline]
    let resources: [SupportTermsResource]
}

struct SupportTermsResource: Equatable, Sendable {
    let link: SupportPageLink
    let translations: SupportTranslationSet?
}

struct SupportTranslationSet: Equatable, Sendable {
    let notice: [SupportContentBlock]
    let lastUpdatedLabel: String?
    let translations: [SupportPageLink]
}

struct SupportGuideContents: Equatable, Sendable {
    let header: SupportPageHeader
    let entries: [SupportContentsEntry]
}

struct SupportContentsEntry: Equatable, Sendable {
    let title: String
    let link: SupportPageLink?
    let children: [SupportContentsEntry]
}
