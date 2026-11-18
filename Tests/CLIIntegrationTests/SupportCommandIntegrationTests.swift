import Foundation
import Testing

@Suite(
    "Support CLI integration",
    .enabled(
        if: ProcessInfo.processInfo.environment["APPLE_DOCS_EXECUTABLE"] != nil,
        "Run with make test-integration INTEGRATION_FILTER=SupportCommandIntegrationTests."),
    .serialized
)
struct SupportCommandIntegrationTests {
    @Test(
        "returns live source catalogs as structured JSON",
        arguments: [
            (["support", "articles", "list"], "articlesCatalog"),
            (["support", "guides", "list"], "helpCatalog"),
            (["support", "guides", "contents", "--name", "app-store-connect"], "guideContents"),
            (["support", "glossary", "list", "--query", "account"], "glossary"),
            (["support", "glossary", "view", "--term", "Account Holder"], "glossaryEntry"),
            (["support", "terms", "list"], "termsCatalog"),
            (["support", "terms", "view", "--name", "apple-developer-program-license-agreement"], "termsEntry"),
        ])
    func liveCatalogs(arguments: [String], kind: String) throws {
        // -- Arrange --
        let arguments = arguments + ["--agent", "--json"]

        // -- Act --
        let output = try runAppleDocs(arguments)
        let value = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])

        // -- Assert --
        #expect(value["kind"] as? String == kind)
        #expect(value["navigation"] != nil)
        #expect(value.count > 2)
    }

    @Test(
        "reads live help and support document layouts",
        arguments: [
            "help/app-store-connect/update-your-app/overview-of-maintaining-an-app",
            "help/app-store-connect/reference/app-information/screenshot-specifications",
            "support/fee-waiver",
            "support/terms/apple-developer-program-license-agreement",
            "support/bimi",
            "support/install-beta",
            "support/technical",
            "support/kernel-extensions",
            "support/forums",
            "support/expiration",
            "support/ipv6",
            "support/sca",
            "support/xcode",
            "support/app-store",
            "support/volume-purchase-and-custom-apps",
            "support/protecting-users-from-suspicious-software",
            "support/required-device-capabilities",
            "support/unlisted-app-distribution",
            "support/dma-and-apps-in-the-eu",
            "support/third-party-SDK-requirements",
            "support/interoperability-requests",
            "support/reader-apps",
            "support/age-assurance",
            "support/app-distribution-in-brazil",
            "support/app-distribution-in-japan",
            "support/apps-in-the-eu",
            "support/storekit-external-entitlement-kr",
            "support/hce-transactions-in-apps",
            "support/nfc-se-platform",
        ])
    func liveDocument(path: String) throws {
        // -- Arrange --
        let arguments = ["support", "view", "--path", path, "--json"]

        // -- Act --
        let output = try runAppleDocs(arguments)
        let value = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
        let content = try #require(value["content"] as? [[String: Any]])

        // -- Assert --
        #expect(value["kind"] as? String == "article")
        #expect(!(value["title"] as? String ?? "").isEmpty)
        #expect(!content.isEmpty)
        #expect(value["navigation"] == nil)
        if path.hasPrefix("support/terms/") {
            let notices = try #require(value["notices"] as? [[String: Any]])
            #expect(!notices.isEmpty)
        }
    }

    @Test("returns a download notice for a live PDF without failing")
    func livePDF() throws {
        // -- Arrange --
        let path = "support/macos-server/macOS-Server-Service-Migration-Guide.pdf"

        // -- Act --
        let output = try runAppleDocs(["support", "view", "--path", path])
        let json = try runAppleDocs(["support", "view", "--path", path, "--agent", "--json"])
        let value = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])

        // -- Assert --
        #expect(output.contains("Page is PDF which cannot be displayed. You can download from:"))
        #expect(
            output.contains("https://developer.apple.com/support/downloads/macOS-Server-Service-Migration-Guide.pdf"))
        #expect(value["kind"] as? String == "pdf")
        #expect(
            value["url"] as? String
                == "https://developer.apple.com/support/downloads/macOS-Server-Service-Migration-Guide.pdf")
    }

    @Test("renders live agent text with follow-up navigation")
    func liveAgentText() throws {
        // -- Arrange --
        let arguments = ["support", "articles", "list", "--category", "membership", "--agent"]

        // -- Act --
        let output = try runAppleDocs(arguments)

        // -- Assert --
        #expect(output.hasPrefix("# Articles\n"))
        #expect(output.contains("apple-docs support"))
        #expect(!output.contains("\u{001B}"))
    }
}
