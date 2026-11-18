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
