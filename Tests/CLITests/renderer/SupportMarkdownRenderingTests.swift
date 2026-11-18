import Foundation
import Testing

@testable import CLI

@Suite("Support Markdown rendering")
struct SupportMarkdownRenderingTests {
    @Test("agent text escapes Markdown syntax without changing human text")
    func escapesText() throws {
        // -- Arrange --
        let text = #"Read *literal* [label] <tag> \path"#
        let payload = SupportPayload.glossaryEntry(
            SupportGlossaryEntry(
                term: "Example", definition: [.paragraph([.text(text)])]))

        // -- Act --
        let agent = try DefaultSupportRenderer(output: .text, audience: .agent).render(payload)
        let human = try DefaultSupportRenderer(output: .text, audience: .human).render(payload)

        // -- Assert --
        #expect(agent.contains(#"Read \*literal\* \[label\] \<tag\> \\path"#))
        #expect(human.contains(text))
    }

    @Test(
        "code span delimiters cannot be closed by literal backticks",
        arguments: [
            ("value`name", "``value`name``"),
            ("`value`", "`` `value` ``"),
            ("value``name", "```value``name```"),
        ])
    func preservesCodeSpans(source: String, expected: String) throws {
        // -- Arrange --
        let payload = SupportPayload.glossaryEntry(
            SupportGlossaryEntry(
                term: "Example", definition: [.paragraph([.code(source)])]))

        // -- Act --
        let output = try DefaultSupportRenderer(output: .text, audience: .agent).render(payload)

        // -- Assert --
        #expect(output.contains(expected))
    }

    @Test("link and image destinations with parentheses remain enclosed")
    func enclosesDestinations() throws {
        // -- Arrange --
        let url = try #require(URL(string: "https://developer.apple.com/support/example_(detail)/"))
        let payload = SupportPayload.glossaryEntry(
            SupportGlossaryEntry(
                term: "Example",
                definition: [
                    .paragraph([
                        .link(label: [.text("[Details]")], url: url),
                        .image(url: url, alt: "[Diagram]"),
                    ]), .image(url: url, alt: "[Block diagram]", caption: []),
                ]))

        // -- Act --
        let output = try DefaultSupportRenderer(output: .text, audience: .agent).render(payload)

        // -- Assert --
        #expect(output.contains(#"[\[Details\]](<https://developer.apple.com/support/example_(detail)/>)"#))
        #expect(output.contains(#"![\[Diagram\]](<https://developer.apple.com/support/example_(detail)/>)"#))
        #expect(output.contains(#"![\[Block diagram\]](<https://developer.apple.com/support/example_(detail)/>)"#))
    }

    @Test("catalog titles, summaries and references escape external Markdown syntax")
    func escapesCatalogText() throws {
        // -- Arrange --
        let url = try #require(URL(string: "https://developer.apple.com/support/example_(detail)/"))
        let payload = SupportPayload.articles(
            SupportArticlesCatalog(
                header: SupportPageHeader(url: url, title: "Support [Guide]", introduction: "Read *first*."),
                categories: [
                    SupportArticleCategory(
                        id: "example", title: "Literal *category*", summary: "Use <literal>.",
                        links: [SupportPageLink(title: "[Open]", url: url)])
                ]))

        // -- Act --
        let output = try DefaultSupportRenderer(output: .text, audience: .agent).render(payload)

        // -- Assert --
        #expect(output.contains(#"# Support \[Guide\]"#))
        #expect(output.contains(#"Read \*first\*."#))
        #expect(output.contains(#"## Literal \*category\*"#))
        #expect(output.contains(#"Use \<literal\>."#))
        #expect(output.contains(#"- [\[Open\]](<https://developer.apple.com/support/example_(detail)/>)"#))
    }
}
