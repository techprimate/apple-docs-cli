import Testing

@testable import CLI

@Suite("Terminal log scrolling")
struct LogPanelTests {
    @Test @MainActor
    func appendedAndEvictedEntriesPreserveTheReadingAnchor() {
        // -- Arrange --
        let entries = (1...8).map {
            SessionLogEntry(id: UInt64($0), level: .warning, label: "test", message: "Entry \($0)")
        }
        let before = LogLayout(entries: entries, width: 100)
        let reading = before.viewport(at: 3, height: 3)
        let after = LogLayout(
            entries: Array(entries.dropFirst(2)) + [
                .init(id: 9, level: .warning, label: "test", message: "New entry")
            ], width: 100)

        // -- Act --
        let position = after.offset(for: reading, height: 3)
        let following = after.offset(for: LogViewport(), height: 3)

        // -- Assert --
        #expect(position == 1)
        #expect(!reading.followsEnd)
        #expect(following == 4)
    }
}
