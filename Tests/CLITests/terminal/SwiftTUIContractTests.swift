import SwiftTUIRuntime
import Testing

@Suite("SwiftTUI public runtime contract")
struct SwiftTUIContractTests {
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
