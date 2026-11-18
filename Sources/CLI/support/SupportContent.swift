import Foundation

indirect enum SupportInline: Encodable, Equatable, Sendable {
    case text(String)
    case code(String)
    case emphasis([SupportInline])
    case strong([SupportInline])
    case superscript([SupportInline])
    case link(label: [SupportInline], url: URL)
    case image(url: URL, alt: String)
    case lineBreak
}

indirect enum SupportContentBlock: Encodable, Equatable, Sendable {
    case paragraph([SupportInline])
    case heading(level: Int, text: String, anchor: String?)
    case list(ordered: Bool, start: Int, items: [[SupportContentBlock]])
    case codeListing(String, syntax: String?)
    case aside(style: String, content: [SupportContentBlock])
    case table([SupportTableRow])
    case image(url: URL, alt: String, caption: [SupportInline])
    case separator
}

struct SupportTableRow: Encodable, Equatable, Sendable {
    let cells: [SupportTableCell]
}

struct SupportTableCell: Encodable, Equatable, Sendable {
    let content: [SupportContentBlock]
    let isHeader: Bool
    let columnSpan: Int
    let rowSpan: Int
}

struct SupportArticle: Encodable, Equatable, Sendable {
    let url: URL
    let title: String
    let context: String?
    let content: [SupportContentBlock]
    let related: [SupportPageLink]
    let notices: [SupportContentBlock]
}
