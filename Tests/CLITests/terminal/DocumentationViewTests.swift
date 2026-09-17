import SwiftTUIRuntime
import Testing

@testable import CLI

@Suite("Terminal documentation presentation")
struct DocumentationViewTests {
    @Test @MainActor
    func duplicateLabelsKeepDistinctTargetsAndWrappedGeometry() throws {
        // -- Arrange --
        let first = DocumentationDestination(technology: "swift", path: "/documentation/swift/string")
        let second = DocumentationDestination(technology: "swift", path: "/documentation/swift/int")
        var page = page()
        page.content = [
            .paragraph([
                .text("Before "), .link(label: [.text("Repeated long label")], target: .documentation(first)),
                .text(" between "), .link(label: [.text("Repeated long label")], target: .documentation(second)),
            ])
        ]

        // -- Act --
        let model = DocumentationViewportModel(page: page, width: 12)
        let links = model.links

        // -- Assert --
        #expect(links.count == 2)
        let firstLink = try #require(links.first)
        let secondLink = try #require(links.last)
        #expect(firstLink.id != secondLink.id)
        #expect(firstLink.target == .documentation(first))
        #expect(secondLink.target == .documentation(second))
        #expect(firstLink.rows.count > 1)
        #expect(secondLink.rows.lowerBound > firstLink.rows.lowerBound)
    }

    @Test @MainActor
    func selectingLinksRevealsThemAndIDsSurviveResize() throws {
        // -- Arrange --
        var page = page()
        page.content = (0..<20).map { .paragraph([.text("Paragraph \($0)")]) }
        page.content.append(
            .paragraph([
                .link(label: [.text("Last reference")], target: .documentation(page.destination))
            ]))
        let narrow = DocumentationViewportModel(page: page, width: 14)
        let wide = DocumentationViewportModel(page: page, width: 60)

        // -- Act --
        let selected = narrow.selectLink(step: 1, viewport: BrowserViewport(), height: 5)
        let restored = wide.restoring(selected, height: 5)
        let link = try #require(narrow.links.first)

        // -- Assert --
        #expect(selected.selectedLinkID == link.id)
        #expect(selected.topRow <= link.rows.lowerBound)
        #expect(selected.topRow + 5 > link.rows.lowerBound)
        #expect(restored.selectedLinkID == selected.selectedLinkID)
        #expect(restored.topRow <= max(0, wide.height - 5))
        #expect(wide.links.first?.id == link.id)
    }

    @Test @MainActor
    func restoredScrollIsNotForcedBackToSelectedLink() {
        // -- Arrange --
        var page = page()
        page.abstract = [.link(label: [.text("First reference")], target: .documentation(page.destination))]
        page.content = (0..<30).map { .paragraph([.text("Line \($0)")]) }
        let model = DocumentationViewportModel(page: page, width: 40)
        let viewport = BrowserViewport(topRow: 20, selectedLinkID: model.links.first?.id)

        // -- Act --
        let restored = model.restoring(viewport, height: 6)

        // -- Assert --
        #expect(restored == viewport)
    }

    @Test @MainActor
    func codeAndUnicodeRemainLiteralAndControlsAreInert() {
        // -- Arrange --
        var page = page()
        page.content = [
            .codeListing(code: ["let x = [`界`, `e\u{301}`]", "\u{1B}[31mnot terminal color\u{7}"], syntax: "swift")
        ]
        let model = DocumentationViewportModel(page: page, width: 50)

        // -- Act --
        let frame = DefaultRenderer().render(
            DocumentationView(model: model, viewport: BrowserViewport(), send: { _ in }),
            proposal: .init(width: 51, height: 15))
        let text = frame.rasterSurface.lines.joined(separator: "\n")

        // -- Assert --
        #expect(text.contains("let x = [`界`, `e\u{301}`]"))
        #expect(text.contains("not terminal color"))
        #expect(!text.contains("\u{1B}"))
        #expect(!text.contains("\u{7}"))
        #expect(model.links.isEmpty)
    }

    @Test @MainActor
    func longDeclarationsAndGroupedReferencesRemainReachable() {
        // -- Arrange --
        var page = page()
        page.declarations = [.init(languages: ["swift"], text: "struct " + String(repeating: "LongName", count: 80))]
        page.topics = [
            .init(
                id: "members", title: "Members",
                references: [
                    .init(
                        id: "member", title: "Nested member", kind: "symbol", target: .documentation(page.destination))
                ])
        ]
        let model = DocumentationViewportModel(page: page, width: 20)

        // -- Act --
        let viewport = model.selectLink(step: 1, viewport: BrowserViewport(), height: 6)
        let frame = DefaultRenderer().render(
            DocumentationView(model: model, viewport: viewport, send: { _ in }),
            proposal: .init(width: 21, height: 6))

        // -- Assert --
        #expect(model.height > 30)
        #expect(frame.rasterSurface.lines.joined(separator: "\n").contains("Nested member"))
        #expect(viewport.topRow > 0)
    }

    @Test @MainActor
    func invisibleLabelsCannotShiftTheNextLinksDestination() {
        // -- Arrange --
        var page = page()
        let visible = DocumentationDestination(technology: "swift", path: "/documentation/swift/visible")
        page.abstract = [
            .link(label: [.text("\n ")], target: .documentation(page.destination)),
            .link(label: [.text("Visible")], target: .documentation(visible)),
        ]

        // -- Act --
        let model = DocumentationViewportModel(page: page, width: 40)

        // -- Assert --
        #expect(model.links.count == 1)
        #expect(model.links.first?.target == .documentation(visible))
    }

    @Test @MainActor
    func unicodeCellWidthsDetermineLinkRows() {
        // -- Arrange --
        var page = page()
        page.abstract = [.text("界界e\u{301} "), .link(label: [.text("XYZ")], target: .documentation(page.destination))]

        // -- Act --
        let model = DocumentationViewportModel(page: page, width: 8)

        // -- Assert --
        // Title is one row, kind wraps to two, and each block has one separating row.
        #expect(model.links.first?.rows.lowerBound == 6)
    }

    @Test @MainActor
    func selectedLinkChangesAppearanceWithoutChangingTextOrDestination() throws {
        // -- Arrange --
        var page = page()
        page.abstract = [.link(label: [.text("Reference")], target: .documentation(page.destination))]
        let model = DocumentationViewportModel(page: page, width: 40)
        let link = try #require(model.links.first)
        let renderer = DefaultRenderer()

        // -- Act --
        let normal = renderer.render(
            DocumentationView(model: model, viewport: BrowserViewport(), send: { _ in }),
            proposal: .init(width: 40, height: 10))
        let selected = renderer.render(
            DocumentationView(model: model, viewport: .init(selectedLinkID: link.id), send: { _ in }),
            proposal: .init(width: 40, height: 10))

        // -- Assert --
        #expect(normal.rasterSurface.lines == selected.rasterSurface.lines)
        #expect(normal.rasterSurface != selected.rasterSurface)
        #expect(link.target == .documentation(page.destination))
    }

    @Test func scrollingUpdatesHistorySnapshotWithoutNavigation() {
        // -- Arrange --
        var state = BrowserState(entry: .type(name: "Example", technology: "Swift"))
        state.currentPage = page()
        state.currentLocation = .page(page().destination)
        let viewport = BrowserViewport(topRow: 12, selectedLinkID: "content/0/link/2")

        // -- Act --
        let effects = BrowserReducer.reduce(state: &state, action: .updateViewport(viewport))

        // -- Assert --
        #expect(effects.isEmpty)
        #expect(state.snapshot?.viewport == viewport)
        #expect(state.currentPage?.title == "Example")
    }

    private func page() -> DocumentationPage {
        DocumentationPage(
            destination: .init(technology: "swift", path: "/documentation/swift/example"),
            title: "Example", kind: "structure")
    }
}
