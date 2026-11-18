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

    @Test("preserves PDF file URLs without adding a directory slash")
    func preservesPDFURL() throws {
        // -- Arrange --
        let path = "support/macos-server/macOS-Server-Service-Migration-Guide.pdf"

        // -- Act --
        let destination = try SupportDestination(path: path)

        // -- Assert --
        #expect(
            destination.url.absoluteString
                == "https://developer.apple.com/support/macos-server/macOS-Server-Service-Migration-Guide.pdf")
    }

    @Test("accepts the Xcode support redirect destination")
    func xcodeRequirements() throws {
        // -- Arrange --
        let url = try #require(URL(string: "https://developer.apple.com/xcode/system-requirements"))

        // -- Act --
        let destination = try SupportDestination(responseURL: url)

        // -- Assert --
        #expect(destination.path == "xcode/system-requirements")
        #expect(destination.url.absoluteString == "https://developer.apple.com/xcode/system-requirements/")
    }

    @Test(
        "rejects unsafe or unsupported input before transport",
        arguments: [
            "", "https://developer.apple.com/help/glossary/", "//example.com/help/glossary", "account/login",
            "help/../account", "help/./glossary", "help/%2e%2e/account", "help/%252e%252e/account",
            "help/foo%2f..%2faccount", "help/glossary?query=secret", "help/glossary#term", "help/foo\\bar",
            "help/foo%5cbar", "help/foo\u{001B}[2J", "help/foo%0a", "help//glossary", "help/foo%3fquery=secret",
            "xcode", "xcode/download", "xcode/system-requirements/other", "xcode/system-requirements/../download",
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
