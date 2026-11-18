import Foundation
import Testing

@testable import CLI

@Suite("Support presentation and output")
struct SupportRendererTests {
    @Test("JSON preserves semantic glossary content and includes navigation only for agents")
    func structuredGlossary() throws {
        // -- Arrange --
        let entry = SupportGlossaryEntry(
            term: "Account Holder",
            definition: [
                .paragraph([
                    .text("The "), .emphasis([.text("owner")]), .text("."),
                ])
            ])
        let value = SupportPayload.glossaryEntry(entry)
        let human = DefaultSupportRenderer(output: .json, audience: .human)
        let agent = DefaultSupportRenderer(output: .json, audience: .agent)

        // -- Act --
        let humanJSON = try object(human.render(value))
        let agentJSON = try object(agent.render(value))

        // -- Assert --
        #expect(humanJSON["kind"] as? String == "glossaryEntry")
        #expect(humanJSON["term"] as? String == "Account Holder")
        #expect(humanJSON["navigation"] == nil)
        let blocks = try #require(humanJSON["definition"] as? [[String: Any]])
        #expect(blocks.first?["type"] as? String == "paragraph")
        let navigation = try #require(agentJSON["navigation"] as? [[String: Any]])
        #expect(
            navigation.first?["command"] as? String
                == "apple-docs support glossary view --term 'Account Holder' --agent")
    }

    @Test("follow-up commands quote names and omit unsupported PDF destinations")
    func navigation() throws {
        // -- Arrange --
        let header = SupportPageHeader(
            url: URL(string: "https://developer.apple.com/support/articles/")!,
            title: "Articles", introduction: "Support resources.")
        let payload = SupportPayload.articles(
            SupportArticlesCatalog(
                header: header,
                categories: [
                    SupportArticleCategory(
                        id: "membership", title: "Membership", summary: "Account resources.",
                        links: [
                            SupportPageLink(
                                title: "Fee waiver",
                                url: URL(string: "https://developer.apple.com/support/fee-waiver/")!),
                            SupportPageLink(
                                title: "PDF", url: URL(string: "https://developer.apple.com/support/guide.pdf")!),
                        ])
                ]))

        // -- Act --
        let text = try DefaultSupportRenderer(output: .text, audience: .agent).render(payload)
        let presentation = SupportPresenter().present(
            .glossaryEntry(
                SupportGlossaryEntry(term: "Developer's account", definition: [])), audience: .agent)

        // -- Assert --
        #expect(text.contains("# Articles"))
        #expect(text.contains("https://developer.apple.com/support/guide.pdf"))
        #expect(text.contains("apple-docs support view --path 'support/fee-waiver' --agent"))
        #expect(!text.contains("--path 'support/guide.pdf'"))
        #expect(presentation.navigation?.first?.command.contains("'Developer'\\''s account'") == true)
    }

    @Test("offers view commands for standalone articles and Xcode support")
    func standaloneNavigation() throws {
        // -- Arrange --
        let paths = SupportArticleFixture.standalone.map(\.path) + ["support/xcode", "xcode/system-requirements"]
        let links = try paths.map { path in
            SupportPageLink(
                title: path, url: try #require(URL(string: "https://developer.apple.com/" + path + "/")))
        }
        let payload = SupportPayload.articles(
            SupportArticlesCatalog(
                header: SupportPageHeader(
                    url: URL(string: "https://developer.apple.com/support/articles/")!,
                    title: "Articles", introduction: ""),
                categories: [SupportArticleCategory(id: "development", title: "Development", summary: "", links: links)]
            ))

        // -- Act --
        let presentation = SupportPresenter().present(payload, audience: .agent)

        // -- Assert --
        #expect(
            presentation.navigation?.map(\.command)
                == paths.map { "apple-docs support view --path '\($0)' --agent" })
    }

    @Test("human rendering keeps table contents, code whitespace and legal notices")
    func humanDocument() throws {
        // -- Arrange --
        let payload = SupportPayload.article(
            SupportArticle(
                url: URL(string: "https://developer.apple.com/support/example/")!, title: "Example", context: "Support",
                content: [
                    .heading(level: 2, text: "Details", anchor: "details"),
                    .table([
                        SupportTableRow(cells: [
                            SupportTableCell(
                                content: [.paragraph([.text("No alpha")])],
                                isHeader: false, columnSpan: 1, rowSpan: 1)
                        ])
                    ]),
                    .codeListing("let value = 1\n  print(value)", syntax: "swift"),
                ], related: [],
                notices: [.paragraph([.text("The accepted version is binding.")])]))

        // -- Act --
        let text = try DefaultSupportRenderer(output: .text, audience: .human).render(payload)

        // -- Assert --
        #expect(text.contains("Example\n"))
        #expect(text.contains("No alpha"))
        #expect(text.contains("  print(value)"))
        #expect(text.contains("The accepted version is binding."))
        #expect(!text.contains("apple-docs support"))
    }

    @Test("terminal output removes control sequences from external page text")
    func removesControls() throws {
        // -- Arrange --
        let payload = SupportPayload.glossaryEntry(
            SupportGlossaryEntry(
                term: "Term\u{001B}[2J", definition: [.paragraph([.text("Text\u{0007}")])]))

        // -- Act --
        let text = try DefaultSupportRenderer(output: .text, audience: .human).render(payload)

        // -- Assert --
        #expect(!text.contains("\u{001B}"))
        #expect(!text.contains("\u{0007}"))
    }

    private func object(_ json: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }
}
