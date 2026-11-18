import Foundation
import SwiftSoup

enum SupportParsingError: Error, Equatable, LocalizedError {
    case unsupportedLayout(String)
    case invalidLink

    var errorDescription: String? {
        switch self {
        case .unsupportedLayout(let path): return "Unsupported or changed Apple support page layout at '\(path)'."
        case .invalidLink: return "Apple support HTML contains an invalid resource link."
        }
    }
}

struct SupportHTMLParser {
    let document: Document
    let source: SupportHTMLDocument

    init(document source: SupportHTMLDocument) throws {
        self.source = source
        document = try SwiftSoup.parse(source.html, source.destination.url.absoluteString)
    }

    func required(_ selector: String, in root: Element? = nil) throws -> Element {
        guard let element = try (root ?? document).select(selector).first() else { throw layoutError }
        return element
    }

    var layoutError: SupportParsingError { .unsupportedLayout(source.destination.path) }

    func canonicalURL() throws -> URL {
        guard let canonical = try document.select("link[rel=canonical][href]").first() else {
            return source.destination.url
        }
        let url = try resolve(canonical.attr("href"))
        guard let destination = try? SupportDestination(responseURL: url) else {
            throw SupportParsingError.invalidLink
        }
        return destination.url
    }

    func header(in root: Element? = nil) throws -> SupportPageHeader {
        let root = try root ?? required("main")
        let heading = try required("h1", in: root)
        return SupportPageHeader(
            url: try canonicalURL(), title: try nonemptyText(heading),
            introduction: try heading.nextElementSibling()?.tagName() == "p"
                ? heading.nextElementSibling()?.text() ?? "" : "")
    }

    func nonemptyText(_ element: Element) throws -> String {
        let text = try element.text()
        guard !text.isEmpty else { throw layoutError }
        return text
    }

    func link(_ element: Element) throws -> SupportPageLink {
        SupportPageLink(title: try nonemptyText(element), url: try resolve(element.attr("href")))
    }

    func links(in element: Element) throws -> [SupportPageLink] {
        try element.select("a[href]").array().map(link)
    }

    func describedLink(_ element: Element) throws -> SupportDescribedLink {
        SupportDescribedLink(
            link: SupportPageLink(
                title: try nonemptyText(required("h3", in: element)),
                url: try resolve(element.attr("href"))),
            summary: try required("p", in: element).text())
    }

    func resolve(_ raw: String) throws -> URL {
        guard !raw.isEmpty, !raw.hasPrefix("//"),
            raw.rangeOfCharacter(from: .controlCharacters) == nil,
            let url = URL(string: raw, relativeTo: source.destination.url)?.absoluteURL,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let scheme = components.scheme?.lowercased(),
            ["https", "http", "mailto"].contains(scheme),
            components.user == nil, components.password == nil
        else { throw SupportParsingError.invalidLink }
        return url
    }

    func articles() throws -> SupportArticlesCatalog {
        let categories = try document.select("main section.section-category").array().map { section in
            SupportArticleCategory(
                id: try section.attr("id"),
                title: try nonemptyText(required("h2", in: section)),
                summary: try required("p", in: section).text(),
                links: try links(in: required("ul.links", in: section)))
        }
        guard !categories.isEmpty, categories.allSatisfy({ !$0.id.isEmpty && !$0.links.isEmpty }) else {
            throw layoutError
        }
        return try SupportArticlesCatalog(header: header(), categories: categories)
    }

    func glossary() throws -> SupportGlossary {
        let entries = try document.select("main article.article").array().map { article in
            SupportGlossaryEntry(
                term: try nonemptyText(required(".article-title", in: article)),
                definition: try blocks(in: required(".article-text", in: article)))
        }
        guard !entries.isEmpty, entries.allSatisfy({ !$0.definition.isEmpty }) else { throw layoutError }
        return try SupportGlossary(header: header(), entries: entries)
    }

    func article() throws -> SupportArticle {
        let article = try required("main .main-content article")
        let heading = try required("main h1")
        let content = try blocks(in: article)
        guard !content.isEmpty else { throw layoutError }
        return SupportArticle(
            url: try canonicalURL(), title: try nonemptyText(heading),
            context: try document.select("main .chapter-name").first()?.text(),
            breadcrumbs: try breadcrumbs(),
            content: content,
            related: try article.select(".LinkUniversal a[href]").array().map(link),
            notices: try document.select("footer .footer-sosumi").array().flatMap { try blocks(in: $0) })
    }

    private func breadcrumbs() throws -> [SupportBreadcrumb] {
        guard let container = try document.select("main .header2 p.custom-text").first() else { return [] }
        return try container.children().array().filter {
            !$0.hasClass("breadcrumb-spacer")
        }.map { element in
            SupportBreadcrumb(
                title: try nonemptyText(element),
                url: element.hasAttr("href") ? try resolve(element.attr("href")) : nil)
        }
    }

    func contents() throws -> SupportGuideContents {
        let root = try required("main nav.sidenav ul.sidenav-list")
        let entries = try contentsEntries(root)
        guard !entries.isEmpty else { throw layoutError }
        return try SupportGuideContents(header: header(in: required("main .main-content")), entries: entries)
    }

    private func contentsEntries(_ root: Element) throws -> [SupportContentsEntry] {
        var entries: [SupportContentsEntry] = []
        for child in root.children() {
            if child.tagName() == "a" {
                let reference = try link(child)
                entries.append(SupportContentsEntry(title: reference.title, link: reference, children: []))
            } else if child.hasClass("list-bold-title") {
                let nested = try child.nextElementSibling()
                let children = try nested?.tagName() == "ul" ? contentsEntries(nested!) : []
                entries.append(SupportContentsEntry(title: try nonemptyText(child), link: nil, children: children))
            }
        }
        return entries
    }
}
