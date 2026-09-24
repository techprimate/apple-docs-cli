import Foundation
import Testing

@testable import CLI

@Suite("Documentation page decoding")
struct DocumentationPageDecoderTests {
    private let memberDestination = DocumentationDestination(
        technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic/member(_:)"
    )

    @Test(
        "decodes technology and collection roles without symbol metadata", arguments: ["collection", "collectionGroup"])
    func decodesNonSymbolPage(role: String) throws {
        // -- Arrange --
        let data = Data(
            """
            {"kind":"article","metadata":{"title":"MetricKit","role":"\(role)"}}
            """.utf8)
        let destination = DocumentationDestination(technology: "metrickit", path: "/documentation/metrickit")

        // -- Act --
        let page = try DocumentationPageDecoder().decode(data, destination: destination)

        // -- Assert --
        #expect(page.title == "MetricKit")
        #expect(page.kind == role)
        #expect(page.modules.isEmpty)
        #expect(page.content.isEmpty)
        #expect(page.topics.isEmpty)
        #expect(page.url.absoluteString == "https://developer.apple.com/documentation/metrickit")
    }

    @Test("retains declarations, availability, deprecation, and labeled inline links")
    func retainsMemberMetadata() throws {
        // -- Arrange --
        let data = DocumentationFixtures.member

        // -- Act --
        let page = try DocumentationPageDecoder().decode(data, destination: memberDestination)

        // -- Assert --
        #expect(page.title == "member(_:)")
        #expect(page.kind == "method")
        #expect(page.modules == ["MetricKit"])
        #expect(
            page.abstract == [
                .text("Read "), .code("value"), .text(" with "),
                .link(
                    label: [.text("a string")],
                    target: .documentation(
                        DocumentationDestination(
                            technology: "swift", path: "/documentation/swift/string"
                        ))), .text("."),
            ])
        #expect(
            page.declarations == [
                DocumentationDeclaration(languages: ["swift"], text: "func member(_ value: String)"),
                DocumentationDeclaration(languages: ["occ"], text: "- (void)member;"),
            ])
        #expect(
            page.availability == [
                DocumentationAvailability(
                    name: "macOS", introducedAt: "15.0", deprecatedAt: "26.0", obsoletedAt: "27.0",
                    isBeta: true, isUnavailable: true
                )
            ])
        #expect(page.deprecation == [.paragraph([.text("Use the replacement.")])])
    }

    @Test("retains nested semantic blocks and unavailable links without inventing destinations")
    func retainsSemanticContent() throws {
        // -- Arrange --
        let data = DocumentationFixtures.member
        let externalURL = try #require(URL(string: "https://example.com/guide"))

        // -- Act --
        let page = try DocumentationPageDecoder().decode(data, destination: memberDestination)

        // -- Assert --
        #expect(
            page.content == [
                .heading("Overview"),
                .paragraph([
                    .link(label: [.text("Guide")], target: .external(externalURL)),
                    .link(label: [.text("Missing")], target: .unavailable("doc://missing")),
                    .link(label: [.text("Unsafe")], target: .unavailable("doc://unsafe")),
                ]),
                .codeListing(code: ["member(\"value\")", ""], syntax: "swift"),
                .orderedList(
                    items: [
                        [
                            .paragraph([.text("First")]), .unorderedList([[.paragraph([.text("Nested")])]]),
                        ]
                    ], startIndex: 3),
                .aside(content: [.paragraph([.text("Take care.")])], style: "warning", name: "Important"),
            ])
        #expect(page.relationships.map(\.title) == ["Conforms To"])
        #expect(page.topics[0].references.map(\.id) == ["doc://string"])
        #expect(page.topics[0].references[0].abstract == [.text("Text storage.")])
        #expect(page.seeAlso[0].references[0].target == .external(externalURL))
    }

    @Test(
        "rejects malformed required metadata and known content",
        arguments: [
            "{}", "not json", #"{"metadata":{"role":"collection"}}"#,
            #"{"metadata":{"title":"","role":"collection"}}"#,
            #"{"metadata":{"title":"Example"}}"#,
            #"{"metadata":{"title":42,"role":"collection"}}"#,
            #"{"metadata":{"title":"Example","role":"collection"},"topicSections":{}}"#,
            #"""
            {"metadata":{"title":"Example","role":"collection"},
             "primaryContentSections":[{"kind":"content","content":[{"type":"paragraph"}]}]}
            """#,
        ])
    func rejectsMalformedPage(json: String) {
        // -- Arrange --
        let data = Data(json.utf8)

        // -- Act --
        let decode = { try DocumentationPageDecoder().decode(data, destination: memberDestination) }

        // -- Assert --
        #expect(throws: (any Error).self) { try decode() }
    }

    @Test("retains topic membership and order, not every reference")
    func retainsTopicMembership() throws {
        // -- Arrange --
        let destination = DocumentationDestination(
            technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic"
        )
        let data = Data(
            """
            {"metadata":{"title":"MXHangDiagnostic","modules":[{"name":"MetricKit"}],
            "roleHeading":"Class","symbolKind":"class"},"abstract":[],
            "primaryContentSections":[],
            "topicSections":[{"title":"Details","identifiers":["doc://member","doc://other"]}],
            "seeAlsoSections":[{"title":"Related","identifiers":["doc://string"]}],
            "references":{
              "doc://other":{"title":"Other member","kind":"symbol","role":"symbol",
                "url":"/documentation/metrickit/mxhangdiagnostic/other"},
              "doc://string":{"title":"String","kind":"symbol","role":"symbol",
                "url":"/documentation/swift/string"},
              "doc://member":{"title":"Example member","kind":"symbol","role":"symbol",
                "url":"/documentation/metrickit/mxhangdiagnostic/member"}}}
            """.utf8)

        // -- Act --
        let page = try DocumentationPageDecoder().decode(data, destination: destination)

        // -- Assert --
        #expect(page.topics.map(\.title) == ["Details"])
        #expect(page.topics[0].references.map(\.title) == ["Example member", "Other member"])
        #expect(
            page.seeAlso[0].references[0].target
                == .documentation(
                    DocumentationDestination(
                        technology: "swift", path: "/documentation/swift/string"
                    )))
    }
}
