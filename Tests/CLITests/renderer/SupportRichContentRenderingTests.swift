import Foundation
import Testing

@testable import CLI

@Suite("Support rich content rendering")
struct SupportRichContentRenderingTests {
    @Test(
        "renders linked inline images without losing text or either URL",
        arguments: [
            OutputAudience.human, .agent,
        ])
    func rendersInlineImages(audience: OutputAudience) throws {
        // -- Arrange --
        let payload = try payload(
            """
            <p>Before <a href='/support/details/'><img src='/images/example.png' alt='Example'></a> after.</p>
            """)
        let renderer = DefaultSupportRenderer(output: .text, audience: audience)

        // -- Act --
        let output = try renderer.render(payload)

        // -- Assert --
        if audience == .agent {
            #expect(
                output.contains(
                    "Before [![Example](https://developer.apple.com/images/example.png)]"
                        + "(https://developer.apple.com/support/details/) after."))
        } else {
            #expect(output.contains("Before Example"))
            #expect(output.contains("https://developer.apple.com/images/example.png"))
            #expect(output.contains("https://developer.apple.com/support/details/"))
            #expect(output.contains("after."))
        }
    }

    @Test("JSON preserves inline image metadata inside its enclosing link")
    func encodesInlineImages() throws {
        // -- Arrange --
        let payload = try payload(
            """
            <p>Before <a href='/support/details/'><img src='/images/example.png' alt='Example'></a> after.</p>
            """)
        let renderer = DefaultSupportRenderer(output: .json, audience: .human)

        // -- Act --
        let output = try renderer.render(payload)
        let json = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
        let blocks = try #require(json["content"] as? [[String: Any]])
        let inline = try #require(blocks.first?["content"] as? [[String: Any]])
        let label = try #require(inline[1]["label"] as? [[String: Any]])
        let image = try #require(label.first)

        // -- Assert --
        #expect(inline[0]["text"] as? String == "Before ")
        #expect(inline[1]["url"] as? String == "https://developer.apple.com/support/details/")
        #expect(image["type"] as? String == "image")
        #expect(image["url"] as? String == "https://developer.apple.com/images/example.png")
        #expect(image["alt"] as? String == "Example")
        #expect(inline[2]["text"] as? String == " after.")
    }

    @Test("explicit paragraph line breaks are preserved for both audiences")
    func preservesParagraphLineBreaks() throws {
        // -- Arrange --
        let payload = try payload("<p>First<br>Second<br><br>Fourth.</p>")
        let human = DefaultSupportRenderer(output: .text, audience: .human)
        let agent = DefaultSupportRenderer(output: .text, audience: .agent)

        // -- Act --
        let humanOutput = try human.render(payload)
        let agentOutput = try agent.render(payload)

        // -- Assert --
        #expect(humanOutput.contains("First\nSecond\n\nFourth."))
        #expect(agentOutput.contains("First\nSecond\n\nFourth."))
    }

    @Test(
        "ordered lists preserve exact numbering across integer boundaries",
        arguments: [
            ("9223372036854775807", "9223372036854775807. First\n9223372036854775808. Second"),
            ("3", "3. First\n4. Second"),
            ("-1", "-1. First\n0. Second"),
            ("-9223372036854775808", "-9223372036854775808. First\n-9223372036854775807. Second"),
        ])
    func rendersLargeListNumbers(start: String, expected: String) throws {
        // -- Arrange --
        let payload = try payload("<ol start='\(start)'><li>First</li><li>Second</li></ol>")
        let human = DefaultSupportRenderer(output: .text, audience: .human)
        let agent = DefaultSupportRenderer(output: .text, audience: .agent)

        // -- Act --
        let humanOutput = try human.render(payload)
        let agentOutput = try agent.render(payload)

        // -- Assert --
        #expect(humanOutput.contains(expected))
        #expect(agentOutput.contains(expected))
    }

    private func payload(_ content: String) throws -> SupportPayload {
        let html = "<main><div class='main-content'><article><h1>Example</h1>" + content + "</article></div></main>"
        let parser = try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/example"), html: html, responseByteCount: html.utf8.count
            ))
        return try .article(parser.article())
    }
}
