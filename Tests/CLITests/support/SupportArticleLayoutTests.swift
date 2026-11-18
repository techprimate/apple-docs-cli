import Foundation
import Testing

@testable import CLI

@Suite("Support article layouts")
struct SupportArticleLayoutTests {
    @Test("rejects an unknown Xcode layout rather than treating page chrome as content")
    func unknownXcodeLayout() throws {
        // -- Arrange --
        let html = "<main><h1>Page Not Found</h1><p>Try a different page.</p></main>"
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "xcode/system-requirements"), html: html,
                responseByteCount: html.utf8.count))

        // -- Act --
        let parse = { try parser.article() }

        // -- Assert --
        #expect(throws: SupportParsingError.unsupportedLayout("xcode/system-requirements")) { try parse() }
    }

    @Test("reads standalone support articles", arguments: SupportArticleFixture.standalone)
    func standalone(fixture: SupportArticleFixture) throws {
        // -- Arrange --
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: fixture.path), html: fixture.html,
                responseByteCount: fixture.html.utf8.count))

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(article.title == fixture.title)
        let first = try #require(article.content.first)
        guard case .paragraph(let content) = first, case .text(let text) = content.first else {
            Issue.record("Expected the article introduction, not navigation or page chrome")
            return
        }
        #expect(text.hasPrefix(fixture.introduction))
        #expect(article.url.absoluteString == "https://developer.apple.com/" + fixture.path + "/")
    }
}
