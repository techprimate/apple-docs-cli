import Foundation
import Testing

@testable import CLI

@Suite("Support HTML parsing")
struct SupportHTMLParserTests {
    @Test("article catalog preserves categories and heterogeneous destinations")
    func articles() throws {
        // -- Arrange --
        let parser = try parser(
            "support/articles",
            """
            <nav><a href='/account'>Account</a></nav><main>
            <h1>Articles</h1><p>Support resources.</p>
            <section class='section-category' id='development'><h2>Development</h2><p>Build apps.</p>
            <ul class='links'><li><a href='/documentation/technotes'>Technotes</a></li>
            <li><a href='/support/guide.pdf'>Guide PDF</a></li></ul></section></main>
            """)

        // -- Act --
        let catalog = try parser.articles()

        // -- Assert --
        #expect(catalog.header.title == "Articles")
        #expect(catalog.categories.count == 1)
        #expect(catalog.categories[0].id == "development")
        #expect(catalog.categories[0].summary == "Build apps.")
        #expect(
            catalog.categories[0].links.map(\.url.absoluteString) == [
                "https://developer.apple.com/documentation/technotes", "https://developer.apple.com/support/guide.pdf",
            ])
    }

    @Test("help catalog retains featured summaries and regional topic subgroups")
    func help() throws {
        // -- Arrange --
        let parser = try parser(
            "help",
            """
            <main><h1>Help guides and articles</h1><p>Learn more.</p>
            <section class='section-guides'><a class='block-link' href='/help/app-store-connect/'>
            <h3>App Store Connect</h3><p>Manage distribution.</p></a></section>
            <section class='section-more'><h2>More topics</h2><div><h3>Account and membership</h3>
            <ul class='links'><li><a href='/help/account/'>Membership</a></li></ul></div>
            <div><h3>Distribution</h3><p>Worldwide</p><ul class='links'>
            <li><a href='/support/app-store/'>App Store</a></li></ul><p>Regional</p>
            <ul class='links'><li><a href='/support/apps-in-the-eu/'>European Union</a></li></ul></div>
            <a class='block-link' href='/help/glossary/'><h3>Glossary</h3><p>Definitions.</p></a>
            </section></main>
            """)

        // -- Act --
        let catalog = try parser.help()

        // -- Assert --
        #expect(catalog.featuredResources[0].summary == "Manage distribution.")
        #expect(catalog.topics.map(\.title) == ["Account and membership", "Distribution"])
        #expect(catalog.topics[0].groups[0].title == nil)
        #expect(catalog.topics[1].groups.map(\.title) == ["Worldwide", "Regional"])
        #expect(catalog.glossary.link.url.absoluteString == "https://developer.apple.com/help/glossary/")
    }

    @Test("terms resolve out-of-main translations to their associated resources")
    func terms() throws {
        // -- Arrange --
        let parser = try parser(
            "support/terms",
            """
            <main><h1>Agreements and guidelines</h1><p>Read the terms.</p><section class='section-terms'>
            <h2 data-sidenav id='program-license-agreements'>Program license agreements</h2>
            <p class='category-intro'>English is binding.</p>
            <h3 data-sidenav id='paid-applications-agreement'>Paid Apps</h3>
            <p>Accept in <a href='https://appstoreconnect.apple.com/'>App Store Connect</a>.</p>
            <p><a class='list-icon-document' href='/agreement/'>View agreement</a></p>
            <p><a class='list-icon-document' href='/terms.pdf'>View agreement (PDF)</a>
            <a class='open-modal modal02' href=''>View translations</a></p>
            <p><a class='list-icon-document' href='/exhibits.pdf'>View exhibits (PDF)</a>
            <a class='open-modal modal03' href=''>View translations</a></p></section></main>
            <div id='modal02' class='modal'><div class='force-height'><p>Convenience translation.</p>
            <p>Last update: October 13, 2026</p><ul><li><a href='/terms-fr.pdf'>Français</a></li></ul></div></div>
            <div id='modal03' class='modal'><div class='force-height'><p>Exhibits notice.</p>
            <ul><li><a href='/exhibits-ja.pdf'>日本語</a></li></ul></div></div>
            """)

        // -- Act --
        let catalog = try parser.terms()
        let entry = try #require(catalog.categories.first?.entries.first)

        // -- Assert --
        #expect(entry.id == "paid-applications-agreement")
        #expect(entry.resources.count == 3)
        #expect(entry.resources[0].translations == nil)
        #expect(entry.resources[1].translations?.lastUpdatedLabel == "October 13, 2026")
        #expect(entry.resources[1].translations?.translations.first?.title == "Français")
        #expect(entry.resources[2].translations?.translations.first?.title == "日本語")
        #expect(
            entry.description.contains(
                .link(
                    label: [.text("App Store Connect")],
                    url: URL(string: "https://appstoreconnect.apple.com/")!)))
    }

    @Test("glossary preserves definition markup without inventing entry identifiers")
    func glossary() throws {
        // -- Arrange --
        let parser = try parser(
            "help/glossary",
            """
            <main><h1>Glossary</h1><p>Definitions.</p><article class='article'>
            <h2 class='article-title'>Account Holder</h2><div class='article-text'>
            <p>The <em>owner</em> manages <a href='/support/roles'>roles</a>.</p>
            <span class='article-keywords hidden'>not visible</span></div></article></main>
            """)

        // -- Act --
        let glossary = try parser.glossary()

        // -- Assert --
        #expect(glossary.entries.map(\.term) == ["Account Holder"])
        #expect(
            glossary.entries[0].definition == [
                .paragraph([
                    .text("The "), .emphasis([.text("owner")]), .text(" manages "),
                    .link(label: [.text("roles")], url: URL(string: "https://developer.apple.com/support/roles")!),
                    .text("."),
                ])
            ])
    }

    @Test("guide contents preserve nested groups rather than curated landing links")
    func contents() throws {
        // -- Arrange --
        let parser = try parser(
            "help/app-store-connect",
            """
            <main><nav class='sidenav'><ul class='sidenav-list'>
            <li class='toggle-all-expand'><button>Expand all</button></li>
            <a href='/help/app-store-connect/release-notes/'><li><p>Release notes</p></li></a>
            <li class='list-bold-title'><p>Reference</p></li><ul class='list-children'>
            <li class='list-bold-title'><p>App information</p></li><ul class='list-children'>
            <a href='/help/app-store-connect/reference/app-information/screenshot-specifications'>
            <li><p>Screenshot specifications</p></li></a>
            </ul></ul></ul></nav><div class='main-content'><h1>App Store Connect Help</h1><p>Manage apps.</p>
            <a href='/contact'>Contact</a></div></main>
            """)

        // -- Act --
        let contents = try parser.contents()

        // -- Assert --
        #expect(contents.entries.count == 2)
        #expect(contents.entries[0].link?.title == "Release notes")
        #expect(contents.entries[1].title == "Reference")
        #expect(contents.entries[1].children[0].title == "App information")
        #expect(contents.entries[1].children[0].children[0].link?.title == "Screenshot specifications")
    }

    @Test("document parsing preserves heading anchors, list starts, tables, notes and related links")
    func article() throws {
        // -- Arrange --
        let parser = try parser(
            "help/app-store-connect/update-your-app/overview",
            """
            <main><nav>Unrelated navigation</nav><div class='main-content'>
            <span class='chapter-name'>Update your app</span><article><h1>Maintain an app</h1><p>Introduction.</p>
            <h2 id='steps'>Steps</h2><ol start='3'><li>Submit <strong>changes</strong>.</li></ol>
            <div class='callout callout-note'><p>Read carefully.</p></div>
            <table><tr><th>Size</th><th>Notes</th></tr><tr><td>10</td><td><p>No alpha.</p></td></tr></table>
            <div class='LinkUniversal'><b>Related</b><a href='../another'>Another article</a></div>
            </article></div></main>
            """)

        // -- Act --
        let article = try parser.article()

        // -- Assert --
        #expect(article.title == "Maintain an app")
        #expect(article.context == "Update your app")
        #expect(article.content.contains(.heading(level: 2, text: "Steps", anchor: "steps")))
        #expect(
            article.content.contains(
                .list(
                    ordered: true, start: 3,
                    items: [
                        [
                            .paragraph([.text("Submit "), .strong([.text("changes")]), .text(".")])
                        ]
                    ])))
        #expect(article.content.contains(.aside(style: "note", content: [.paragraph([.text("Read carefully.")])])))
        #expect(
            article.related.first?.url.absoluteString
                == "https://developer.apple.com/help/app-store-connect/update-your-app/another")
        #expect(
            article.content.contains {
                if case .table(let rows) = $0 { return rows.count == 2 }
                return false
            })
    }

    @Test("missing layouts and unsafe links fail explicitly")
    func rejectsUnsupportedLayout() throws {
        // -- Arrange --
        let empty = try parser("support/articles", "<main><h1>Sign in</h1></main>")
        let unsafe = try parser(
            "support/articles",
            """
            <main><h1>Articles</h1><p>Intro</p><section class='section-category' id='membership'>
            <h2>Membership</h2><p>Info</p><ul class='links'><a href='javascript:alert(1)'>Bad link</a></ul>
            </section></main>
            """)

        // -- Act --
        let parseEmpty = { try empty.articles() }
        let parseUnsafe = { try unsafe.articles() }

        // -- Assert --
        #expect(throws: SupportParsingError.self) { try parseEmpty() }
        #expect(throws: SupportParsingError.self) { try parseUnsafe() }
        #expect(throws: SupportParsingError.self) { try empty.article() }
    }

    private func parser(_ path: String, _ html: String) throws -> SupportHTMLParser {
        try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: path), html: html, responseByteCount: html.utf8.count))
    }
}
