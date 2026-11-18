import Foundation

extension SupportInline {
    private enum CodingKeys: CodingKey { case type, text, content, label, url, alt, name }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .image(let url, let alt):
            try container.encode("image", forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encode(alt, forKey: .alt)
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .code(let text):
            try container.encode("code", forKey: .type)
            try container.encode(text, forKey: .text)
        case .emphasis(let content):
            try container.encode("emphasis", forKey: .type)
            try container.encode(content, forKey: .content)
        case .strong(let content):
            try container.encode("strong", forKey: .type)
            try container.encode(content, forKey: .content)
        case .superscript(let content):
            try container.encode("superscript", forKey: .type)
            try container.encode(content, forKey: .content)
        case .link(let label, let url):
            try container.encode("link", forKey: .type)
            try container.encode(label, forKey: .label)
            try container.encode(url, forKey: .url)
        case .anchor(let name, let content):
            try container.encode("anchor", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(content, forKey: .content)
        case .lineBreak:
            try container.encode("lineBreak", forKey: .type)
        }
    }
}

extension SupportContentBlock {
    private enum CodingKeys: CodingKey {
        case type, content, level, text, anchor, ordered, start, items, syntax, style, rows, url, alt, caption
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paragraph(let content):
            try container.encode("paragraph", forKey: .type)
            try container.encode(content, forKey: .content)
        case .heading(let level, let text, let anchor):
            try container.encode("heading", forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(anchor, forKey: .anchor)
        case .list(let ordered, let start, let items):
            try container.encode("list", forKey: .type)
            try container.encode(ordered, forKey: .ordered)
            try container.encode(start, forKey: .start)
            try container.encode(items, forKey: .items)
        case .codeListing(let text, let syntax):
            try container.encode("codeListing", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(syntax, forKey: .syntax)
        case .aside(let style, let content):
            try container.encode("aside", forKey: .type)
            try container.encode(style, forKey: .style)
            try container.encode(content, forKey: .content)
        case .table(let rows):
            try container.encode("table", forKey: .type)
            try container.encode(rows, forKey: .rows)
        case .image(let url, let alt, let caption):
            try container.encode("image", forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encode(alt, forKey: .alt)
            try container.encode(caption, forKey: .caption)
        case .separator:
            try container.encode("separator", forKey: .type)
        }
    }
}
