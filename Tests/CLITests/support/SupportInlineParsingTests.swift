import Foundation
import Testing

@testable import CLI

@Suite("Support inline parsing boundaries")
struct SupportInlineParsingTests {
    @Test("preserves the interoperability page's Feedback Assistant submission link")
    func feedbackAssistantLink() throws {
        // -- Arrange --
        let html = """
            <main><article><section class='section section-enrollment'><div class='section-content'>
            <h1>Interoperability requests</h1><div id='message-option1' class='hidden'>
            <h4>This appears to be an interoperability request.</h4>
            <p><a href='applefeedback://new?form_identifier=dev.tech&amp;answers%5B%3Aarea%5D=seed%3Ainterop'
            class='button'>Submit request<span class='loc-en-only'></span></a></p>
            </div></div></section></article></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/interoperability-requests"), html: html,
                responseByteCount: html.utf8.count))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        let url = try #require(
            URL(string: "applefeedback://new?form_identifier=dev.tech&answers%5B%3Aarea%5D=seed%3Ainterop"))
        #expect(
            article.content.last == .paragraph([.link(label: [.text("Submit request")], url: url)]))
    }

    @Test(
        "rejects executable and local-file links",
        arguments: ["javascript:alert(1)", "data:text/html,bad", "file:///etc/passwd"])
    func rejectsUnsafeLinks(url: String) throws {
        // -- Arrange --
        let html = """
            <main><article><h1>Interoperability requests</h1><p><a href='\(url)'>Submit request</a></p></article></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/interoperability-requests"), html: html,
                responseByteCount: html.utf8.count))

        // -- Act --
        let parse = { try parser.article() }

        // -- Assert --
        #expect(throws: SupportParsingError.invalidLink) { try parse() }
    }

    @Test("direct inline code does not absorb later sibling content")
    func directInlineCode() throws {
        // -- Arrange --
        let html = """
            <main><div class='main-content'><article><h1>Instructions</h1>
            <ul><li>Run <code>first()</code> then <code>second()</code>.</li></ul>
            <p>Separate paragraph.</p></article></div></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/example"), html: html, responseByteCount: html.utf8.count
            ))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(
            article.content == [
                .list(
                    ordered: false, start: 1,
                    items: [
                        [
                            .paragraph([
                                .text("Run "), .code("first()"), .text(" then "), .code("second()"), .text("."),
                            ])
                        ]
                    ]),
                .paragraph([.text("Separate paragraph.")]),
            ])
    }

    @Test("paragraphs and links retain meaningful inline images in order")
    func preservesInlineImages() throws {
        // -- Arrange --
        let html = """
            <main><div class='main-content'><article><h1>Instructions</h1>
            <p>Before <img src='/images/example.png' alt='Example'> after.</p>
            <p><a href='/support/details/'><img src='/images/linked.png' alt='Linked example'></a></p>
            </article></div></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/example"), html: html, responseByteCount: html.utf8.count
            ))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(
            article.content == [
                .paragraph([
                    .text("Before "),
                    .image(url: URL(string: "https://developer.apple.com/images/example.png")!, alt: "Example"),
                    .text(" after."),
                ]),
                .paragraph([
                    .link(
                        label: [
                            .image(
                                url: URL(string: "https://developer.apple.com/images/linked.png")!,
                                alt: "Linked example")
                        ], url: URL(string: "https://developer.apple.com/support/details/")!)
                ]),
            ])
    }

    @Test("inline images preserve sentence flow in list items and table cells")
    func preservesImagesInBlockContainers() throws {
        // -- Arrange --
        let html = """
            <main><div class='main-content'><article><h1>Instructions</h1>
            <ul><li>Before <img src='/images/example.png' alt='Example'> after.</li></ul>
            <table><tr><td>Before <img src='/images/example.png' alt='Example'> after.</td></tr></table>
            </article></div></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/example"), html: html, responseByteCount: html.utf8.count
            ))
        let paragraph = SupportContentBlock.paragraph([
            .text("Before "),
            .image(url: URL(string: "https://developer.apple.com/images/example.png")!, alt: "Example"),
            .text(" after."),
        ])

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(
            article.content == [
                .list(ordered: false, start: 1, items: [[paragraph]]),
                .table([
                    SupportTableRow(cells: [
                        SupportTableCell(
                            content: [paragraph], isHeader: false, columnSpan: 1, rowSpan: 1)
                    ])
                ]),
            ])
    }

    @Test("mixed-content wrappers retain nested block boundaries")
    func preservesBlocksInsideEdits() throws {
        // -- Arrange --
        let html = """
            <main><div class='main-content'><article><h1>Instructions</h1>
            <del><p>First removed paragraph.</p><p>Second removed paragraph.</p></del>
            </article></div></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/example"), html: html, responseByteCount: html.utf8.count
            ))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(
            article.content == [
                .paragraph([.text("First removed paragraph.")]), .paragraph([.text("Second removed paragraph.")]),
            ])
    }

    @Test(
        "phrasing elements stay within surrounding paragraphs",
        arguments: [
            "kbd", "sub", "u", "small", "abbr", "cite", "mark", "del", "ins", "s", "time",
        ])
    func keepsPhrasingInline(tag: String) throws {
        // -- Arrange --
        let html = """
            <main><div class='main-content'><article><h1>Instructions</h1>
            <ul><li>Before <\(tag)>middle</\(tag)> after.</li></ul>
            </article></div></main>
            """
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/example"), html: html, responseByteCount: html.utf8.count
            ))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(
            article.content == [
                .list(
                    ordered: false, start: 1,
                    items: [
                        [
                            .paragraph([
                                .text("Before "), .text("middle"), .text(" after."),
                            ])
                        ]
                    ])
            ])
    }
}
