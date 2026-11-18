import Foundation
import Logging
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Support command execution")
struct SupportCommandExecutionTests {
    @Test("runs all support operations through the real service and renderer", arguments: executionCases)
    func executes(arguments: [String], kind: String) async throws {
        // -- Arrange --
        let command = try #require(CLI.parseAsRoot(arguments + ["--json", "--agent"]) as? any SupportExecutableCommand)
        let deps = try ExecutionDependencies()

        // -- Act --
        try await command.run(deps: deps)
        let output = try #require(deps.output.lines.first)
        let value = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])

        // -- Assert --
        #expect(deps.output.lines.count == 1)
        #expect(value["kind"] as? String == kind)
        #expect(value["navigation"] != nil)
        #expect(deps.telemetry.commands.count == 1)
    }

    @Test("PDF views print a download notice without failing", arguments: [false, true])
    func pdfNotice(agent: Bool) async throws {
        // -- Arrange --
        let arguments =
            ["support", "view", "--path", "support/macos-server/macOS-Server-Service-Migration-Guide.pdf"]
            + (agent ? ["--agent"] : [])
        let command = try #require(CLI.parseAsRoot(arguments) as? SupportViewCommand)
        let deps = try ExecutionDependencies()

        // -- Act --
        try await command.run(deps: deps)
        let output = try #require(deps.output.lines.first)

        // -- Assert --
        #expect(deps.output.lines.count == 1)
        #expect(output.contains("Page is PDF which cannot be displayed. You can download from:"))
        #expect(
            output.contains("https://developer.apple.com/support/downloads/macOS-Server-Service-Migration-Guide.pdf"))
        #expect(!output.contains(".pdf/"))
    }

    @Test("PDF JSON exposes the download destination", arguments: [false, true])
    func pdfJSON(agent: Bool) async throws {
        // -- Arrange --
        let arguments =
            [
                "support", "view", "--path", "support/macos-server/macOS-Server-Service-Migration-Guide.pdf", "--json",
            ] + (agent ? ["--agent"] : [])
        let command = try #require(CLI.parseAsRoot(arguments) as? SupportViewCommand)
        let deps = try ExecutionDependencies()

        // -- Act --
        try await command.run(deps: deps)
        let output = try #require(deps.output.lines.first)
        let value = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])

        // -- Assert --
        #expect(value["kind"] as? String == "pdf")
        #expect(
            value["url"] as? String
                == "https://developer.apple.com/support/downloads/macOS-Server-Service-Migration-Guide.pdf")
        #expect(value["message"] as? String == "Page is PDF which cannot be displayed. You can download from:")
        #expect(value["content"] == nil)
        #expect((value["navigation"] != nil) == agent)
    }

    @Test("propagates a missing selection without writing successful output")
    func selectionFailure() async throws {
        // -- Arrange --
        let command = try #require(
            CLI.parseAsRoot([
                "support", "glossary", "view", "--term", "Missing",
            ]) as? SupportGlossaryViewCommand)
        let deps = try ExecutionDependencies()

        // -- Act --
        let run = { try await command.run(deps: deps) }

        // -- Assert --
        await #expect(throws: SupportServiceError.self) { try await run() }
        #expect(deps.output.lines.isEmpty)
    }
}

private let executionCases: [([String], String)] = [
    (["support", "articles", "list", "--category", "membership"], "articlesCatalog"),
    (["support", "guides", "list"], "helpCatalog"),
    (["support", "guides", "contents", "--name", "app-store-connect"], "guideContents"),
    (["support", "glossary", "list", "--query", "account"], "glossary"),
    (["support", "glossary", "view", "--term", "Account Holder"], "glossaryEntry"),
    (["support", "terms", "list", "--category", "guidelines"], "termsCatalog"),
    (["support", "terms", "view", "--name", "app-review-guidelines"], "termsEntry"),
    (["support", "view", "--path", "support/fee-waiver"], "article"),
]

private typealias ExecutionProviders = AppleSupportServiceProvider & SupportRendererProvider
    & CommandOutputWriterProvider & TelemetryProvider

private struct ExecutionDependencies: ExecutionProviders {
    let telemetry = RecordingCommandTelemetry()
    let output = RecordingCommandOutputWriter()
    var commandOutputWriter: RecordingCommandOutputWriter { output }
    let supportService: DefaultAppleSupportService<DefaultAppleSupportClient<HTTPTestTransport>>

    init() throws {
        var responses: [URL: HTTPTestTransport.Response] = [:]
        for (path, html) in executionHTML {
            let url = try SupportDestination(path: path).url
            let response = try #require(
                HTTPURLResponse(
                    url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"]))
            responses[url] = .response(data: Data(html.utf8), response: response)
        }
        let pdfURL = try #require(
            URL(string: "https://developer.apple.com/support/macos-server/macOS-Server-Service-Migration-Guide.pdf"))
        let downloadURL = try #require(
            URL(string: "https://developer.apple.com/support/downloads/macOS-Server-Service-Migration-Guide.pdf"))
        let pdfResponse = try #require(
            HTTPURLResponse(
                url: downloadURL, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/pdf"]))
        responses[pdfURL] = .response(data: Data("%PDF-1.3".utf8), response: pdfResponse)
        supportService = DefaultAppleSupportService(
            dependencies: DefaultAppleSupportClient(
                logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
                dependencies: HTTPTestTransport(responses: responses)))
    }

    func supportRenderer(output: OutputOptions) -> DefaultSupportRenderer {
        DefaultSupportRenderer(output: output.format, audience: output.audience)
    }
}

private let executionHTML = [
    "support/articles": """
    <main><h1>Articles</h1><p>Resources.</p><section class='section-category' id='membership'>
    <h2>Membership</h2><p>Accounts.</p><ul class='links'><a href='/support/fee-waiver/'>Fee waiver</a></ul>
    </section></main>
    """,
    "help": """
    <main><h1>Help guides and articles</h1><p>Resources.</p><section class='section-guides'>
    <a class='block-link' href='/help/app-store-connect/'><h3>App Store Connect</h3><p>Manage apps.</p></a>
    </section><section class='section-more'><h2>More topics</h2><div><h3>Membership</h3><ul class='links'>
    <a href='/help/account/'>Account</a></ul></div><a class='block-link' href='/help/glossary/'>
    <h3>Glossary</h3><p>Terms.</p></a></section></main>
    """,
    "help/app-store-connect": """
    <main><nav class='sidenav'><ul class='sidenav-list'>
    <a href='/help/app-store-connect/release-notes/'><li>Release notes</li></a></ul></nav>
    <div class='main-content'><h1>App Store Connect Help</h1><p>Manage apps.</p></div></main>
    """,
    "help/glossary": """
    <main><h1>Glossary</h1><p>Definitions.</p><article class='article'>
    <h2 class='article-title'>Account Holder</h2><div class='article-text'><p>Manages membership.</p>
    </div></article></main>
    """,
    "support/terms": """
    <main><h1>Terms</h1><p>Agreements and guidelines.</p><section class='section-terms'>
    <h2 data-sidenav id='guidelines'>Guidelines</h2>
    <h3 data-sidenav id='app-review-guidelines'>App Review Guidelines</h3><p>Review criteria.</p>
    <p><a class='list-icon-document' href='/app-store/review/guidelines/'>View guidelines</a></p>
    </section></main>
    """,
    "support/fee-waiver": """
    <main><div class='main-content'><span class='chapter-name'>Membership</span>
    <article><h1>Fee waiver</h1><p>Eligible organizations.</p></article></div></main>
    """,
]
