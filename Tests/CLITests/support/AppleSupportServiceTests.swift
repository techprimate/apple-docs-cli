import Foundation
import Logging
import Testing

@testable import CLI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Apple support service")
struct AppleSupportServiceTests {
    @Test("filters article categories using source identifiers")
    func filtersCategories() async throws {
        // -- Arrange --
        let service = try service(
            "support/articles",
            """
            <main><h1>Articles</h1><p>Support</p>
            <section class='section-category' id='membership'><h2>Membership</h2><p>Accounts</p>
            <ul class='links'><a href='/support/account/'>Account</a></ul></section>
            <section class='section-category' id='development'><h2>Development</h2><p>Tools</p>
            <ul class='links'><a href='/support/xcode/'>Xcode</a></ul></section></main>
            """)

        // -- Act --
        let catalog = try await service.fetchArticles(category: "development")

        // -- Assert --
        #expect(catalog.categories.map(\.id) == ["development"])
        await #expect(throws: SupportServiceError.self) {
            try await service.fetchArticles(category: "missing")
        }
    }

    @Test("glossary name queries are case insensitive without matching definition text")
    func queriesTerms() async throws {
        // -- Arrange --
        let service = try service("help/glossary", glossaryHTML)

        // -- Act --
        let list = try await service.fetchGlossary(query: "HOLDER")
        let entry = try await service.fetchGlossaryEntry(term: "account holder")
        let definitionOnly = try await service.fetchGlossary(query: "membership")

        // -- Assert --
        #expect(list.entries.map(\.term) == ["Account Holder"])
        #expect(entry.term == "Account Holder")
        #expect(definitionOnly.entries.isEmpty)
        await #expect(throws: SupportServiceError.self) {
            try await service.fetchGlossaryEntry(term: "Account")
        }
    }

    @Test("terms entry lookup uses the source identifier and preserves resources")
    func looksUpTermsEntry() async throws {
        // -- Arrange --
        let service = try service(
            "support/terms",
            """
            <main><h1>Terms</h1><p>Read carefully.</p><section class='section-terms'>
            <h2 data-sidenav id='guidelines'>Guidelines</h2>
            <h3 data-sidenav id='app-review-guidelines'>App Review Guidelines</h3><p>Review criteria.</p>
            <p><a class='list-icon-document' href='/app-store/review/guidelines/'>View guidelines</a></p>
            </section></main>
            """)

        // -- Act --
        let entry = try await service.fetchTermsEntry(named: "app-review-guidelines")
        let catalog = try await service.fetchTerms(category: "guidelines")

        // -- Assert --
        #expect(entry.title == "App Review Guidelines")
        #expect(
            entry.resources[0].link.url.absoluteString == "https://developer.apple.com/app-store/review/guidelines/")
        #expect(catalog.categories.map(\.id) == ["guidelines"])
        await #expect(throws: SupportServiceError.self) {
            try await service.fetchTermsEntry(named: "missing")
        }
    }

    @Test("document view parses only recognized content containers")
    func fetchesArticle() async throws {
        // -- Arrange --
        let service = try service(
            "support/fee-waiver",
            """
            <main><div class='main-content'><span class='chapter-name'>Membership</span>
            <article><h1>Fee waiver</h1><p>Eligible organizations.</p></article></div></main>
            """)

        // -- Act --
        let document = try await service.fetchDocument(path: "support/fee-waiver")

        // -- Assert --
        guard case .article(let article) = document else {
            Issue.record("Expected an HTML article")
            return
        }
        #expect(article.title == "Fee waiver")
        #expect(article.content == [.paragraph([.text("Eligible organizations.")])])
    }

    @Test("reads the Xcode support redirect and its requirements table")
    func fetchesXcodeRequirements() async throws {
        // -- Arrange --
        let destination = try SupportDestination(path: "support/xcode")
        let finalURL = try #require(URL(string: "https://developer.apple.com/xcode/system-requirements"))
        let html = """
            <head><link rel='canonical' href='https://developer.apple.com/xcode/system-requirements/'></head>
            <nav><h2>Xcode</h2><a href='/download/'>Download</a></nav>
            <main id='main' class='main' role='main'>
            <section class='section section-hero'><div class='section-content'>
            <h1 class='typography-headline'>SDKs and system requirements</h1></div></section>
            <section class='section section-requirements'><div class='section-content'>
            <developer-accordion><accordion-panel id='previous-versions'>
            <h3>Previous Xcode versions</h3><div><table class='typography-caption'>
            <thead><tr><th>Xcode Version</th><th>Supported macOS Versions</th><th>SDKs</th></tr></thead>
            <tbody><tr><td>Xcode&nbsp;15.4</td><td>macOS&nbsp;Sonoma&nbsp;14.x</td>
            <td>iOS&nbsp;17.5<br>tvOS&nbsp;17.5</td></tr></tbody></table></div>
            </accordion-panel></developer-accordion></div></section></main>
            <aside>Unrelated router links</aside><footer><nav>Developer Footer</nav></footer>
            """
        let response = try #require(
            HTTPURLResponse(
                url: finalURL, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"]))
        let service = Service(
            dependencies: DefaultAppleSupportClient(
                logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() },
                dependencies: HTTPTestTransport(responses: [
                    destination.url: .response(data: Data(html.utf8), response: response)
                ])))

        // -- Act --
        let document = try await service.fetchDocument(path: "support/xcode")

        // -- Assert --
        guard case .article(let article) = document else {
            Issue.record("Expected an HTML article")
            return
        }
        #expect(article.title == "SDKs and system requirements")
        #expect(article.url.absoluteString == "https://developer.apple.com/xcode/system-requirements/")
        #expect(article.content.first == .heading(level: 3, text: "Previous Xcode versions", anchor: nil))
        let table = try #require(article.content.last)
        guard case .table(let rows) = table else {
            Issue.record("Expected the requirements table without page chrome")
            return
        }
        #expect(rows.count == 2)
        #expect(rows[0].cells.map(\.isHeader) == [true, true, true])
        #expect(rows[1].cells[0].content == [.paragraph([.text("Xcode 15.4")])])
        #expect(rows[1].cells[2].content == [.paragraph([.text("iOS 17.5"), .lineBreak, .text("tvOS 17.5")])])
    }

    @Test(
        "guide identifiers reject paths and cannot escape the guide root",
        arguments: [
            "../account", "app-store-connect/reference", "https://example.com", "", "app-store-connect?query=x",
        ])
    func rejectsGuideIdentifier(name: String) async throws {
        // -- Arrange --
        let service = try service("help/glossary", glossaryHTML)

        // -- Act --
        let fetch = { try await service.fetchGuideContents(named: name) }

        // -- Assert --
        await #expect(throws: SupportServiceError.invalidGuideName) { try await fetch() }
    }

    private typealias Service = DefaultAppleSupportService<DefaultAppleSupportClient<HTTPTestTransport>>

    private func service(_ path: String, _ html: String) throws -> Service {
        let destination = try SupportDestination(path: path)
        let response = try #require(
            HTTPURLResponse(
                url: destination.url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"]))
        let transport = HTTPTestTransport(responses: [
            destination.url: .response(data: Data(html.utf8), response: response)
        ])
        return DefaultAppleSupportService(
            dependencies: DefaultAppleSupportClient(
                logger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }, dependencies: transport))
    }
}

private let glossaryHTML = """
    <main><h1>Glossary</h1><p>Definitions.</p><article class='article'>
    <h2 class='article-title'>Account Holder</h2><div class='article-text'><p>Manages membership.</p></div></article>
    <article class='article'><h2 class='article-title'>Admin</h2><div class='article-text'><p>Manages users.</p>
    </div></article></main>
    """
