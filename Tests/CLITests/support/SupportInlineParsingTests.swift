import Foundation
import Testing

@testable import CLI

@Suite("Support inline parsing boundaries")
struct SupportInlineParsingTests {
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
