import SwiftSoup

extension SupportHTMLParser {
    func terms() throws -> SupportTermsCatalog {
        let section = try required("main .section-terms")
        let categories = try section.select("h2[data-sidenav]").array().map { heading in
            var introduction: [SupportContentBlock] = []
            var entries: [SupportTermsEntry] = []
            var sibling = try heading.nextElementSibling()
            while let current = sibling, current.tagName() != "h2" {
                if current.tagName() == "h3" {
                    entries.append(try termsEntry(current))
                } else if current.hasClass("category-intro") {
                    introduction += try block(current)
                }
                sibling = try current.nextElementSibling()
            }
            return try SupportTermsCategory(
                id: heading.attr("id"), title: nonemptyText(heading), introduction: introduction, entries: entries)
        }
        guard !categories.isEmpty, categories.allSatisfy({ !$0.id.isEmpty && !$0.entries.isEmpty }) else {
            throw layoutError
        }
        return try SupportTermsCatalog(header: header(), categories: categories)
    }

    private func termsEntry(_ heading: Element) throws -> SupportTermsEntry {
        var description: [SupportInline] = []
        var resources: [SupportTermsResource] = []
        var sibling = try heading.nextElementSibling()
        while let current = sibling, !["h2", "h3"].contains(current.tagName()) {
            let anchors = try current.select("a.list-icon-document").array()
            if !anchors.isEmpty {
                resources += try termsResources(in: current)
            } else if current.tagName() == "p" {
                if !description.isEmpty { description.append(.text(" ")) }
                description += try inline(in: current)
            }
            sibling = try current.nextElementSibling()
        }
        let id = try heading.attr("id")
        guard !id.isEmpty, !resources.isEmpty else { throw layoutError }
        return try SupportTermsEntry(
            id: id, title: nonemptyText(heading), description: description, resources: resources)
    }

    private func termsResources(in container: Element) throws -> [SupportTermsResource] {
        var resources: [SupportTermsResource] = []
        for anchor in try container.select("a.list-icon-document, a.open-modal") {
            if anchor.hasClass("list-icon-document") {
                resources.append(SupportTermsResource(link: try link(anchor), translations: nil))
            } else {
                guard let index = resources.indices.last, resources[index].translations == nil else {
                    throw layoutError
                }
                resources[index] = SupportTermsResource(
                    link: resources[index].link, translations: try translationSet(anchor))
            }
        }
        return resources
    }

    private func translationSet(_ trigger: Element) throws -> SupportTranslationSet {
        let targets = try trigger.classNames().compactMap { try document.getElementById($0) }
        guard let target = targets.first(where: { $0.hasClass("modal") }) else { throw layoutError }
        let modal = try required(".force-height", in: target)
        var notice: [SupportContentBlock] = []
        var updated: String?
        for child in modal.children() where child.tagName() == "p" {
            let text = try child.text()
            if text.hasPrefix("Last update:") {
                updated = String(text.dropFirst("Last update:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                notice += try block(child)
            }
        }
        let translations = try modal.select("li a[href]").array().map(link)
        guard !translations.isEmpty else { throw layoutError }
        return SupportTranslationSet(notice: notice, lastUpdatedLabel: updated, translations: translations)
    }
}
