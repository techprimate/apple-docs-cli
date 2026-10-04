import Testing

@testable import CLI

@Suite("Browser terminal screen")
struct BrowserTerminalScreenTests {
    @Test("applies cursor movement and partial row updates to the visible screen")
    func partialUpdates() {
        // -- Arrange --
        let output = "\u{1B}[2J\u{1B}[H\r\u{1B}[2KFirst\r\u{1B}[1B\r\u{1B}[2KSecond\u{1B}[1A\rLast"

        // -- Act --
        let screen = BrowserTerminalScreen.render(output, columns: 12, rows: 2)

        // -- Assert --
        #expect(screen == "Lastt\nSecond")
    }

    @Test("clears rows that are replaced with shorter content")
    func clearedRows() {
        // -- Arrange --
        let output = "\u{1B}[HLong entry\r\u{1B}[2KNew"

        // -- Act --
        let screen = BrowserTerminalScreen.render(output, columns: 12, rows: 1)

        // -- Assert --
        #expect(screen == "New")
    }
}
