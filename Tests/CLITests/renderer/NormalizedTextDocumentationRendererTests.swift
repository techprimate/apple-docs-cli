import Foundation
import Testing

@testable import CLI

@Suite("Normalized human documentation text")
struct NormalizedTextDocumentationRendererTests {
    @Test("retains readable sections and every normalized declaration without agent chrome")
    func rendersPage() throws {
        // -- Arrange --
        let destination = DocumentationDestination(
            technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic/member(_:)"
        )
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        let presentation = DocumentationPresenter().page(page, audience: .human)

        // -- Act --
        let output = HumanDocumentationRenderer().render(presentation)

        // -- Assert --
        #expect(output.hasPrefix("member(_:)\n━━━━━━━━━━\nMethod · MetricKit\nSymbol kind: method"))
        #expect(output.contains("  Read `value` with a string."))
        #expect(output.contains("func member(_ value: String)"))
        #expect(output.contains("- (void)member;"))
        #expect(output.contains("Availability\n────────────"))
        #expect(output.contains("Deprecated\n──────────"))
        #expect(output.contains("  3. First\n\n     • Nested"))
        #expect(output.contains("  Important\n  │ Take care."))
        #expect(output.contains("Text storage."))
        #expect(output.contains("https://developer.apple.com/documentation/swift/string"))
        #expect(output.contains("https://example.com/guide"))
        #expect(output.hasSuffix("https://developer.apple.com/documentation/metrickit/mxhangdiagnostic/member(_:)"))
        #expect(!output.contains("apple-docs types"))
        #expect(!output.contains("javascript:"))
    }

    @Test("preserves Apple's role heading rather than guessing from symbol kind")
    func preservesRoleHeading() throws {
        // -- Arrange --
        let data = Data(
            #"""
            {"metadata":{"title":"value","symbolKind":"property","roleHeading":"Instance Property"}}
            """#.utf8)
        let destination = DocumentationDestination(technology: "swift", path: "/documentation/swift/value")
        let page = try DocumentationPageDecoder().decode(data, destination: destination)

        // -- Act --
        let output = HumanDocumentationRenderer().render(DocumentationPresenter().page(page, audience: .human))

        // -- Assert --
        #expect(output.contains("Instance Property\nSymbol kind: property"))
    }

    @Test("retains human availability ranges")
    func rendersAvailabilityRange() {
        // -- Arrange --
        let page = DocumentationPage(
            destination: DocumentationDestination(technology: "swift", path: "/documentation/swift/string"),
            title: "String", kind: "struct",
            availability: [DocumentationAvailability(name: "macOS", introducedAt: "15.0", deprecatedAt: "26.0")]
        )

        // -- Act --
        let output = HumanDocumentationRenderer().render(DocumentationPresenter().page(page, audience: .human))

        // -- Assert --
        #expect(output.contains("15.0–26.0"))
    }

    @Test("does not emit remote terminal controls")
    func sanitizesTerminalText() {
        // -- Arrange --
        let page = DocumentationPage(
            destination: DocumentationDestination(technology: "swift", path: "/documentation/swift/string"),
            title: "String\u{001B}[2J", kind: "struct", abstract: [.text("A\u{009B}31m string.")]
        )

        // -- Act --
        let output = HumanDocumentationRenderer().render(DocumentationPresenter().page(page, audience: .human))

        // -- Assert --
        #expect(output.contains("string."))
        #expect(!output.contains("\u{001B}"))
        #expect(!output.contains("\u{009B}"))
    }
}
