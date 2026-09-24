import Foundation
import Testing

@testable import CLI

@Suite("Documentation audience presentations")
struct DocumentationPresentationTests {
    @Test("audiences retain identical normalized content while agent references add navigation")
    func preservesContentParity() throws {
        // -- Arrange --
        let destination = DocumentationDestination(
            technology: "metrickit", path: "/documentation/metrickit/mxhangdiagnostic/member(_:)"
        )
        let page = try DocumentationPageDecoder().decode(DocumentationFixtures.member, destination: destination)
        let presenter = DocumentationPresenter()

        // -- Act --
        let human = presenter.page(page, audience: .human)
        let agent = presenter.page(page, audience: .agent)

        // -- Assert --
        #expect(human.document == page)
        #expect(agent.document == page)
        #expect(human.navigation == nil)
        #expect(
            agent.navigation?.command
                == "apple-docs types view 'mxhangdiagnostic/member(_:)' --technology 'metrickit' --agent")
        #expect(human.topics[0].references[0].navigation == nil)
        #expect(
            agent.topics[0].references[0].navigation?.command
                == "apple-docs types view 'string' --technology 'swift' --agent")
        #expect(agent.seeAlso[0].references[0].navigation == nil)
    }

    @Test("technology roots use the supported list command")
    func presentsRootNavigation() {
        // -- Arrange --
        let page = DocumentationPage(
            destination: DocumentationDestination(technology: "swiftui", path: "/documentation/swiftui"),
            title: "SwiftUI", kind: "collection"
        )

        // -- Act --
        let presentation = DocumentationPresenter().page(page, audience: .agent)

        // -- Assert --
        #expect(presentation.navigation?.path == nil)
        #expect(presentation.navigation?.command == "apple-docs types list --technology 'swiftui' --agent")
    }

    @Test("shell arguments preserve apostrophes, spaces, substitutions, and overload punctuation")
    func quotesArguments() {
        // -- Arrange --
        let input = "O'Brien `cmd` $(cmd) value(_:)"

        // -- Act --
        let quoted = shellQuote(input)

        // -- Assert --
        #expect(quoted == "'O'\\''Brien `cmd` $(cmd) value(_:)'")
    }

    @Test("does not fabricate commands for external or unrepresentable symbol destinations")
    func omitsUnsupportedCommands() {
        // -- Arrange --
        let symbols = [
            DocumentationType(name: "External", kind: "symbol", path: "external", url: "https://example.com"),
            DocumentationType(
                name: "Exact dots", kind: "symbol", path: "member.with.dots",
                url: "https://developer.apple.com/documentation/swift/member.with.dots"),
        ]

        // -- Act --
        let presentations = DocumentationPresenter().symbols(symbols, technology: "Swift", audience: .agent)

        // -- Assert --
        #expect(presentations.allSatisfy { $0.navigation == nil })
        #expect(presentations.map(\.name) == ["External", "Exact dots"])
    }

    @Test("operator paths beginning with a dash follow the option terminator")
    func quotesOperatorPath() {
        // -- Arrange --
        let page = DocumentationPage(
            destination: DocumentationDestination(technology: "swift", path: "/documentation/swift/-(_:_:)"),
            title: "-(_:_:)", kind: "func"
        )

        // -- Act --
        let presentation = DocumentationPresenter().page(page, audience: .agent)

        // -- Assert --
        #expect(
            presentation.navigation?.command == "apple-docs types view --technology 'swift' --agent -- '-(_:_:)'"
        )
    }

    @Test("technology presentation retains identifiers and only adds supported root navigation")
    func presentsTechnologies() {
        // -- Arrange --
        let technologies = [
            Technology(name: "SwiftUI", identifier: "doc://com.apple.documentation/documentation/SwiftUI"),
            Technology(name: "External", identifier: "https://example.com"),
        ]

        // -- Act --
        let presentations = DocumentationPresenter().technologies(technologies, audience: .agent)

        // -- Assert --
        #expect(presentations.map(\.identifier) == technologies.map(\.identifier))
        #expect(presentations[0].navigation?.command == "apple-docs types list --technology 'swiftui' --agent")
        #expect(presentations[1].navigation == nil)
    }
}
