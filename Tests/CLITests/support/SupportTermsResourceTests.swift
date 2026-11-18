import Foundation
import Testing

@testable import CLI

@Suite("Support terms resource associations")
struct SupportTermsResourceTests {
    @Test("document links in a shared paragraph keep their own translation groups")
    func pairsGroupedResources() throws {
        // -- Arrange --
        let parser = try parser(
            resources: """
                <p><a class='list-icon-document' href='/first.pdf'>First PDF</a>
                <a class='open-modal modal02' href=''>First translations</a>
                <a class='list-icon-document' href='/second.pdf'>Second PDF</a>
                <a class='open-modal modal03' href=''>Second translations</a></p>
                """)

        // -- Act --
        let catalog = try parser.terms()
        let resources = try #require(catalog.categories.first?.entries.first?.resources)

        // -- Assert --
        #expect(resources.count == 2)
        #expect(resources[0].translations?.translations.map(\.title) == ["Français"])
        #expect(resources[1].translations?.translations.map(\.title) == ["日本語"])
    }

    @Test("a translation trigger does not apply to preceding untranslated documents")
    func leavesUntranslatedResourcesAlone() throws {
        // -- Arrange --
        let parser = try parser(
            resources: """
                <p><a class='list-icon-document' href='/first.pdf'>First PDF</a>
                <a class='list-icon-document' href='/second.pdf'>Second PDF</a>
                <a class='open-modal modal03' href=''>Second translations</a></p>
                """)

        // -- Act --
        let catalog = try parser.terms()
        let resources = try #require(catalog.categories.first?.entries.first?.resources)

        // -- Assert --
        #expect(resources[0].translations == nil)
        #expect(resources[1].translations?.translations.map(\.title) == ["日本語"])
    }

    @Test("modal classes must identify a translation modal, not share a prefix")
    func resolvesActualModal() throws {
        // -- Arrange --
        let parser = try parser(
            resources: """
                <p><a class='list-icon-document' href='/first.pdf'>First PDF</a>
                <a class='open-modal modal-trigger modal02' href=''>Translations</a></p>
                <div id='modal-trigger'>Not a translation modal.</div>
                """)

        // -- Act --
        let catalog = try parser.terms()
        let resource = try #require(catalog.categories.first?.entries.first?.resources.first)

        // -- Assert --
        #expect(resource.translations?.translations.map(\.title) == ["Français"])
    }

    private func parser(resources: String) throws -> SupportHTMLParser {
        let html = """
            <main><h1>Terms</h1><p>Read the terms.</p><section class='section-terms'>
            <h2 data-sidenav id='program-license-agreements'>Program license agreements</h2>
            <h3 data-sidenav id='agreement'>Agreement</h3><p>Description.</p>
            \(resources)</section></main>
            <div id='modal02' class='modal'><div class='force-height'><p>First notice.</p>
            <ul><li><a href='/first-fr.pdf'>Français</a></li></ul></div></div>
            <div id='modal03' class='modal'><div class='force-height'><p>Second notice.</p>
            <ul><li><a href='/second-ja.pdf'>日本語</a></li></ul></div></div>
            """
        return try SupportHTMLParser(
            document: SupportHTMLDocument(
                destination: SupportDestination(path: "support/terms"), html: html, responseByteCount: html.utf8.count))
    }
}
