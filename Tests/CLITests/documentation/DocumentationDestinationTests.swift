import Foundation
import Testing

@testable import CLI

@Suite("Documentation destinations")
struct DocumentationDestinationTests {
    private let current = DocumentationDestination(
        technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic"
    )

    @Test("preserves overload punctuation and fragments across technologies")
    func resolvesCrossTechnologyLink() throws {
        // -- Arrange --
        let raw = "https://developer.apple.com/documentation/swift/array/append(_:)-7x2#Discussion"

        // -- Act --
        let target = try DocumentationDestination.resolve(raw, relativeTo: current)

        // -- Assert --
        #expect(
            target
                == .documentation(
                    DocumentationDestination(
                        technology: "swift", path: "/documentation/swift/array/append(_:)-7x2", fragment: "Discussion"
                    )))
    }

    @Test("resolves relative paths without changing exact symbol spelling")
    func resolvesRelativePath() throws {
        // -- Arrange --
        let raw = "mxhangdiagnostic/member.with.dots(_:)"

        // -- Act --
        let target = try DocumentationDestination.resolve(raw, relativeTo: current)

        // -- Assert --
        #expect(
            target
                == .documentation(
                    DocumentationDestination(
                        technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic/member.with.dots(_:)"
                    )))
    }

    @Test("fragment-only navigation keeps the page")
    func resolvesFragment() throws {
        // -- Arrange --
        let raw = "#Overview"

        // -- Act --
        let target = try DocumentationDestination.resolve(raw, relativeTo: current)

        // -- Assert --
        #expect(
            target
                == .documentation(
                    DocumentationDestination(
                        technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic", fragment: "Overview"
                    )))
    }

    @Test(
        "website links never become documentation fetches",
        arguments: [
            "https://example.com/documentation/swift", "http://developer.apple.com/documentation/swift",
            "https://developer.apple.com/videos/play/wwdc2026/123",
            "https://developer.apple.com.evil.test/documentation/swift",
        ])
    func resolvesExternalLink(raw: String) throws {
        // -- Arrange --
        let expectedURL = try #require(URL(string: raw))

        // -- Act --
        let target = try DocumentationDestination.resolve(raw, relativeTo: current)

        // -- Assert --
        #expect(target == .external(expectedURL))
    }

    @Test("DocC identifiers need the page reference dictionary")
    func unresolvedIdentifier() throws {
        // -- Arrange --
        let raw = "doc://com.apple.metrickit/documentation/MetricKit/MXHangDiagnostic"

        // -- Act --
        let target = try DocumentationDestination.resolve(raw, relativeTo: current)

        // -- Assert --
        #expect(target == .unavailable(raw))
    }

    @Test(
        "rejects unsafe destinations",
        arguments: [
            "javascript:alert(1)", "file:///etc/passwd", "data:text/plain,hello",
            "https://user:password@developer.apple.com/documentation/swift",
            "https://example.com/../secret", "/documentation/swift/../secret",
            "/documentation/swift/%2e%2e/secret", "/documentation/swift/%252e%252e/secret",
            "/documentation/swift/foo%2f..%2fsecret", "/documentation/swift/foo\\bar",
            "/documentation/swift/foo%5cbar", "/documentation/swift/foo\u{001B}[2J",
            "/documentation/swift/foo%0a", "https://developer.apple.com:444/documentation/swift",
            "//evil.test/documentation/swift",
        ])
    func rejectsUnsafeDestination(raw: String) {
        // -- Arrange --
        let destination = current

        // -- Act --
        let resolve = { try DocumentationDestination.resolve(raw, relativeTo: destination) }

        // -- Assert --
        #expect(throws: (any Error).self) { try resolve() }
    }
}
