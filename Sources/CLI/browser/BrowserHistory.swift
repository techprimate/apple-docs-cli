struct BrowserHistoryEntry: Equatable, Sendable {
    let location: BrowserLocation
    var viewport = BrowserViewport()
    var navigator = NavigatorSnapshot()
    var focus: BrowserFocus = .document
}

struct BrowserHistory: Equatable, Sendable {
    private var entries: [BrowserHistoryEntry] = []
    private var cursor = -1

    var current: BrowserHistoryEntry? {
        cursor >= 0 ? entries[cursor] : nil
    }

    mutating func visit(_ entry: BrowserHistoryEntry) {
        entries = Array(entries.prefix(cursor + 1))
        entries.append(entry)
        cursor = entries.count - 1
    }

    mutating func updateCurrent(_ entry: BrowserHistoryEntry) {
        guard cursor >= 0 else { return }
        entries[cursor] = entry
    }

    mutating func back() -> BrowserHistoryEntry? {
        guard cursor > 0 else { return nil }
        cursor -= 1
        return current
    }

    mutating func forward() -> BrowserHistoryEntry? {
        guard cursor + 1 < entries.count else { return nil }
        cursor += 1
        return current
    }
}
