import SwiftTUIRuntime
import Testing

@Suite("SwiftTUI public runtime contract")
struct SwiftTUIContractTests {
    @Test @MainActor
    func exposesDistinctWrappedInlineLinkRegions() throws {
        // -- Arrange --
        let first = Link("Repeated long label", destination: .init("https://example.com/first"))
        let second = Link("Repeated long label", destination: .init("https://example.com/second"))
        let content: Text.RichContent = "Before \(first) between \(second) after"

        // -- Act --
        let frame = DefaultRenderer().render(Text(content), proposal: .init(width: 12, height: nil))
        let regions = frame.semanticSnapshot.focusRegions

        // -- Assert --
        #expect(regions.count == 2)
        let firstRegion = try #require(regions.first)
        let secondRegion = try #require(regions.last)
        #expect(firstRegion.identity != secondRegion.identity)
        #expect(firstRegion.rect.size.height > 1)
        #expect(secondRegion.rect.origin.y > firstRegion.rect.origin.y)
    }

    @Test @MainActor
    func rendersTwoIndependentPanes() {
        // -- Arrange --
        let view = HStack(spacing: 2) {
            Text("Navigator")
            Text("Documentation")
        }

        // -- Act --
        let frame = DefaultRenderer().render(view, proposal: .init(width: 60, height: 4))
        let text = frame.rasterSurface.lines.joined(separator: "\n")

        // -- Assert --
        #expect(text.contains("Navigator"))
        #expect(text.contains("Documentation"))
    }
}
