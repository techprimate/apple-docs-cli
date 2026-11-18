import SwiftSoup

extension SupportHTMLParser {
    func help() throws -> SupportHelpCatalog {
        let featured = try document.select("main .section-guides a.block-link").array().map(describedLink)
        let more = try required("main .section-more")
        let glossaryCard = try required("a.block-link[href='/help/glossary/']", in: more)
        let glossaryHeading = try glossaryCard.select("h3").first()
        let headings = try more.select("h3").array().filter { $0 !== glossaryHeading }
        let topics = try headings.map { heading in
            var groups: [SupportTopicLinkGroup] = []
            var groupTitle: String?
            var sibling = try heading.nextElementSibling()
            while let current = sibling, current.tagName() != "h3" {
                if current.tagName() == "p" {
                    groupTitle = try current.text()
                } else if current.tagName() == "ul" {
                    groups.append(SupportTopicLinkGroup(title: groupTitle, links: try links(in: current)))
                    groupTitle = nil
                }
                sibling = try current.nextElementSibling()
            }
            return try SupportHelpTopic(title: nonemptyText(heading), groups: groups)
        }
        guard !featured.isEmpty, !topics.isEmpty, topics.allSatisfy({ !$0.groups.isEmpty }) else {
            throw layoutError
        }
        return try SupportHelpCatalog(
            header: header(), featuredResources: featured, topicsTitle: nonemptyText(required("h2", in: more)),
            topics: topics, glossary: describedLink(glossaryCard))
    }
}
