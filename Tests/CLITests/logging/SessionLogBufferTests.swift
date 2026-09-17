import Testing

@testable import CLI

@Suite("Session log buffer", .timeLimit(.minutes(1)))
struct SessionLogBufferTests {
    @Test("retains the newest entries within capacity")
    func boundsStorage() {
        // -- Arrange --
        let buffer = SessionLogBuffer(capacity: 2)
        let first = SessionLogEntry(id: 1, level: .warning, label: "test", message: "first")
        let second = SessionLogEntry(id: 2, level: .warning, label: "test", message: "second")
        let third = SessionLogEntry(id: 3, level: .warning, label: "test", message: "third")

        // -- Act --
        [first, second, third].forEach(buffer.append)

        // -- Assert --
        #expect(buffer.snapshot().map(\.message) == ["second", "third"])
        #expect(buffer.snapshot().map(\.id) == [2, 3])
    }

    @Test("concurrent writers receive ordered unique IDs in bounded storage")
    func serializesConcurrentAppends() async {
        // -- Arrange --
        let buffer = SessionLogBuffer(capacity: 100)

        // -- Act --
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<1000 {
                group.addTask {
                    buffer.append(SessionLogEntry(level: .debug, label: "test", message: "Entry \(index)"))
                }
            }
        }

        // -- Assert --
        let entries = buffer.snapshot()
        #expect(entries.count == 100)
        #expect(entries.map(\.id) == Array(UInt64(901)...UInt64(1000)))
    }

    @Test("a burst produces one wakeup until its snapshot is consumed")
    func coalescesChanges() async {
        // -- Arrange --
        let buffer = SessionLogBuffer()
        var changes = buffer.changes.makeAsyncIterator()
        for index in 1...3 {
            buffer.append(SessionLogEntry(level: .warning, label: "test", message: "Entry \(index)"))
        }

        // -- Act --
        let firstWakeup = await changes.next()
        let firstSnapshot = buffer.snapshot()
        buffer.append(SessionLogEntry(level: .error, label: "test", message: "Later"))
        let secondWakeup = await changes.next()

        // -- Assert --
        #expect(firstWakeup == 1)
        #expect(firstSnapshot.count == 3)
        #expect(secondWakeup == 4)
        #expect(buffer.snapshot().last?.message == "Later")
    }
}
