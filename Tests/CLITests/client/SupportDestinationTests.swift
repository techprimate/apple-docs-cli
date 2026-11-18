import Foundation
import Testing

@testable import CLI

@Suite("Support destinations")
struct SupportDestinationTests {
    @Test("normalizes optional boundary slashes without changing case")
    func normalizesPath() throws {
        // -- Arrange --
        let raw = "/support/D-U-N-S/"

        // -- Act --
        let destination = try SupportDestination(path: raw)

        // -- Assert --
        #expect(destination.path == "support/D-U-N-S")
        #expect(destination.url.absoluteString == "https://developer.apple.com/support/D-U-N-S/")
    }

    @Test(
        "rejects unsafe or unsupported input before transport",
        arguments: [
            "", "https://developer.apple.com/help/glossary/", "//example.com/help/glossary", "account/login",
            "help/../account", "help/./glossary", "help/%2e%2e/account", "help/%252e%252e/account",
            "help/foo%2f..%2faccount", "help/glossary?query=secret", "help/glossary#term", "help/foo\\bar",
            "help/foo%5cbar", "help/foo\u{001B}[2J", "help/foo%0a", "help//glossary", "help/foo%3fquery=secret",
        ])
    func rejectsPath(raw: String) {
        // -- Arrange --
        let path = raw

        // -- Act --
        let build = { try SupportDestination(path: path) }

        // -- Assert --
        #expect(throws: AppleSupportClientError.invalidPath) { try build() }
    }
}
