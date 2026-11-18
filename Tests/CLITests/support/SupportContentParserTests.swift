import Foundation
import Testing

@testable import CLI

@Suite("Support rich content parsing")
struct SupportContentParserTests {
    @Test("preserves code whitespace, table spans, figures and footnote markers")
    func preservesContent() throws {
        // -- Arrange --
        let html = """
            <main><div class='main-content'><article><h1>Content</h1>
            <p>Note<sup>1</sup> and <code>value</code>.</p>
            <pre><code class='language-swift'>let value = 1
              print(value)</code></pre>
            <table><tr><th colspan='2'>Heading</th></tr><tr><td rowspan='2'>Value</td><td>Other</td></tr></table>
            <figure><img src='/images/example.png' alt='Example'><figcaption>A <em>caption</em>.</figcaption></figure>
            <img src='/decorative.svg' alt=''><script>invisible()</script>
            </article></div></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/example"), html: html, responseByteCount: html.utf8.count
            ))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(article.content.contains(.codeListing("let value = 1\n  print(value)", syntax: "swift")))
        #expect(
            article.content.contains(
                .paragraph([
                    .text("Note"), .superscript([.text("1")]), .text(" and "), .code("value"), .text("."),
                ])))
        #expect(
            article.content.contains { block in
                if case .table(let rows) = block {
                    return rows[0].cells[0].columnSpan == 2 && rows[1].cells[0].rowSpan == 2
                }
                return false
            })
        #expect(
            article.content.contains(
                .image(
                    url: URL(string: "https://developer.apple.com/images/example.png")!, alt: "Example",
                    caption: [.text("A "), .emphasis([.text("caption")]), .text(".")])))
        #expect(article.content.count == 4)
    }

    @Test("preserves ordered breadcrumbs including unlinked category labels")
    func preservesBreadcrumbs() throws {
        // -- Arrange --
        let html = """
            <main><div class='header2'><p class='custom-text'>
            <a href='/help/app-store-connect/'>App Store Connect</a><span class='breadcrumb-spacer'>/</span>
            <span class='lighter'>Reference</span><span class='breadcrumb-spacer'>/</span>
            <a href='/help/app-store-connect/reference/app-information/'>App information</a>
            <span class='breadcrumb-spacer'>/</span><span class='lighter'>Specifications</span></p></div>
            <div class='main-content'><article><h1>Specifications</h1><p>Details.</p></article></div></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(
                    path: "help/app-store-connect/reference/app-information/specifications"),
                html: html, responseByteCount: html.utf8.count))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(
            article.breadcrumbs.map(\.title) == [
                "App Store Connect", "Reference", "App information", "Specifications",
            ])
        #expect(article.breadcrumbs[0].url?.absoluteString == "https://developer.apple.com/help/app-store-connect/")
        #expect(article.breadcrumbs[1].url == nil)
    }

    @Test("uses validated canonical metadata for articles served through a support alias")
    func canonicalArticleURL() throws {
        // -- Arrange --
        let html = """
            <head><link rel='canonical' href='https://developer.apple.com/help/account/membership/fee-waivers/'></head>
            <main><div class='main-content'><article><h1>Fee waiver</h1><p>Details.</p></article></div></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/fee-waiver"), html: html,
                responseByteCount: html.utf8.count))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(article.url.absoluteString == "https://developer.apple.com/help/account/membership/fee-waivers/")
    }

    @Test("named anchors without href preserve their content and navigation target")
    func retainsNamedAnchors() throws {
        // -- Arrange --
        let html = """
            <main><div class='main-content'><article><h1>Agreement</h1>
            <p>Terms <a name='OLE_LINK24'></a><a name='OLE_LINK25'>survive</a>.</p>
            </article></div></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/terms/example"), html: html,
                responseByteCount: html.utf8.count))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(
            article.content == [
                .paragraph([
                    .text("Terms "), .anchor(name: "OLE_LINK24", content: []),
                    .anchor(name: "OLE_LINK25", content: [.text("survive")]), .text("."),
                ])
            ])
    }

    @Test("retains legal section anchors and substantive footer notices")
    func retainsLegalNotices() throws {
        // -- Arrange --
        let html = """
            <main><h1>License Agreement</h1><div class='main-content'><article>
            <h3 id='ADPLA1'>1. Acceptance</h3><p>Terms apply.</p>
            <h3 id='S1'>Schedule 1</h3><p>Schedule text.</p></article></div></main>
            <footer><section class='footer-sosumi'><ul><li>The accepted version is binding.
            <ul><li>Schedule 1 last updated October 29, 2026.</li></ul></li></ul></section>
            <nav>Unrelated footer navigation</nav></footer>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/terms/apple-developer-program-license-agreement"),
                html: html, responseByteCount: html.utf8.count))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(article.content.first == .heading(level: 3, text: "1. Acceptance", anchor: "ADPLA1"))
        #expect(article.content.contains(.heading(level: 3, text: "Schedule 1", anchor: "S1")))
        #expect(
            article.notices == [
                .list(
                    ordered: false, start: 1,
                    items: [
                        [
                            .paragraph([.text("The accepted version is binding. ")]),
                            .list(
                                ordered: false, start: 1,
                                items: [
                                    [
                                        .paragraph([.text("Schedule 1 last updated October 29, 2026.")])
                                    ]
                                ]),
                        ]
                    ])
            ])
    }
}
