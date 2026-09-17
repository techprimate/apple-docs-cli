import Foundation
import SwiftTUIRuntime

struct DocumentationTextLink {
    let id: String
    let target: DocumentationLinkTarget
}

struct DocumentationTextBlock: Identifiable {
    let id: String
    let content: [DocumentationInline]
    var isHeading = false

    var links: [DocumentationTextLink] {
        content.enumerated().compactMap { index, inline in
            guard case .link(let label, let target) = inline,
                !terminalSafeText(label.map(\.text).joined()).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            if case .unavailable = target { return nil }
            return DocumentationTextLink(id: "\(id)/link/\(index)", target: target)
        }
    }

    @MainActor func text(selectedLinkID: String? = nil) -> Text {
        var interpolation = Text.StringInterpolation(literalCapacity: 0, interpolationCount: content.count)
        for (index, inline) in content.enumerated() {
            let label = terminalSafeText(inline.text)
            switch inline {
            case .text:
                interpolation.appendLiteral(label)
            case .code:
                interpolation.appendInterpolation(Text(label).italic())
            case .link(_, let target):
                guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    interpolation.appendLiteral(label)
                    continue
                }
                let selected = selectedLinkID == "\(id)/link/\(index)"
                let text = Text(label).bold(selected).underline()
                switch target {
                case .documentation(let destination):
                    interpolation.appendInterpolation(Link(text, destination: .init(destination.url.absoluteString)))
                case .external(let url):
                    interpolation.appendInterpolation(Link(text, destination: .init(url.absoluteString)))
                case .unavailable:
                    interpolation.appendLiteral(label)
                }
            }
        }
        return Text(Text.RichContent(stringInterpolation: interpolation)).bold(isHeading)
    }
}

struct DocumentationViewContent {
    private(set) var blocks: [DocumentationTextBlock] = []

    init(presentation: PagePresentation) {
        let page = presentation.document
        heading(page.title, id: "title")
        paragraph(
            [
                .text(
                    [page.roleHeading ?? page.kind, page.modules.joined(separator: ", ")]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
            ], id: "kind")
        paragraph(page.abstract, id: "abstract")
        append(page.deprecation, path: "deprecation")
        if !page.declarations.isEmpty { heading("Declaration", id: "declarations") }
        for (index, declaration) in page.declarations.enumerated() {
            paragraph([.code(declaration.text)], id: "declarations/\(index)")
        }
        if !page.availability.isEmpty { heading("Availability", id: "availability") }
        let formatter = DocumentationContentRenderer(audience: .human)
        for (index, platform) in page.availability.enumerated() {
            paragraph([.text(platform.name + " " + formatter.availability(platform))], id: "availability/\(index)")
        }
        append(page.content, path: "content")
        groups(presentation.relationships, title: "Relationships", path: "relationships")
        groups(presentation.topics, title: "Topics", path: "topics")
        groups(presentation.seeAlso, title: "See Also", path: "seeAlso")
    }

    init(state: BrowserState) {
        if let page = state.currentPage {
            self.init(presentation: DocumentationPresenter().page(page, audience: .human))
            return
        }
        self.init()
        let technology = state.technology
        let root = DocumentationDestination(technology: technology ?? "", path: "/documentation/" + (technology ?? ""))
        if let technology {
            heading("Symbols · " + technology, id: "catalog")
            if let error = state.catalog.typeErrors[technology] {
                paragraph([.text(error + " · r: retry")], id: "error")
            }
            if state.catalog.pendingTypes[technology] != nil { paragraph([.text("Loading symbols…")], id: "loading") }
            for (index, symbol) in (state.catalog.types[technology] ?? []).enumerated() {
                let target =
                    (try? DocumentationDestination.resolve(symbol.url, relativeTo: root)) ?? .unavailable(symbol.name)
                paragraph(
                    [.link(label: [.text(symbol.name)], target: target), .text(" · " + symbol.kind)],
                    id: "symbol/\(index)")
                paragraph([.text(symbol.path)], id: "symbol/\(index)/path")
            }
        } else {
            heading("Technologies", id: "catalog")
            if let error = state.catalog.technologiesError { paragraph([.text(error + " · r: retry")], id: "error") }
            if state.catalog.pendingTechnologiesID != nil { paragraph([.text("Loading technologies…")], id: "loading") }
            for (index, technology) in state.catalog.technologies.enumerated() {
                let path = URLComponents(string: technology.identifier)?.path ?? ""
                let target =
                    (try? DocumentationDestination.resolve("https://developer.apple.com" + path, relativeTo: root))
                    ?? .unavailable(technology.name)
                paragraph([.link(label: [.text(technology.name)], target: target)], id: "technology/\(index)")
            }
        }
    }

    private init() {}

    private mutating func heading(_ text: String, id: String) {
        blocks.append(.init(id: id, content: [.text(text)], isHeading: true))
    }

    private mutating func paragraph(_ content: [DocumentationInline], id: String) {
        guard !content.isEmpty else { return }
        blocks.append(.init(id: id, content: content))
    }

    private mutating func append(_ content: [DocumentationBlock], path: String) {
        for (index, block) in content.enumerated() {
            let id = "\(path)/\(index)"
            switch block {
            case .paragraph(let inline): paragraph(inline, id: id)
            case .heading(let title): heading(title, id: id)
            case .codeListing(let lines, _): paragraph([.code(lines.joined(separator: "\n"))], id: id)
            case .orderedList(let items, let start): list(items, start: start, path: id)
            case .unorderedList(let items): list(items, start: nil, path: id)
            case .aside(let content, let style, let name):
                heading(name ?? style.capitalized, id: id)
                append(content, path: id + "/aside")
            }
        }
    }

    private mutating func list(_ items: [[DocumentationBlock]], start: Int?, path: String) {
        for (index, item) in items.enumerated() {
            let id = "\(path)/item/\(index)"
            let marker = start.map { "\($0 + index). " } ?? "• "
            if case .paragraph(let inline) = item.first {
                paragraph([.text(marker)] + inline, id: id)
                append(Array(item.dropFirst()), path: id)
            } else {
                paragraph([.text(marker)], id: id)
                append(item, path: id)
            }
        }
    }

    private mutating func groups(_ groups: [GroupPresentation], title: String, path: String) {
        guard !groups.isEmpty else { return }
        heading(title, id: path)
        for (index, group) in groups.enumerated() {
            let groupID = "\(path)/\(index)"
            heading(group.title, id: groupID)
            for (index, presented) in group.references.enumerated() {
                let reference = presented.reference
                let id = "\(groupID)/reference/\(index)"
                paragraph([.link(label: [.text(reference.title)], target: reference.target)], id: id)
                paragraph(reference.abstract, id: id + "/abstract")
            }
        }
    }
}
