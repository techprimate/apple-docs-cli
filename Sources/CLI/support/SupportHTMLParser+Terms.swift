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
                let translations = try current.select("a.open-modal").first().map(translationSet)
                for anchor in anchors {
                    resources.append(SupportTermsResource(link: try link(anchor), translations: translations))
                }
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

    private func translationSet(_ trigger: Element) throws -> SupportTranslationSet {
        let modalClass = try trigger.classNames().first { $0.hasPrefix("modal") }
        guard let modalClass else { throw layoutError }
        let modal = try required("#" + modalClass + " .force-height")
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
