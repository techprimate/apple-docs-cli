import SwiftTUIRuntime

struct LogViewport {
    var entryID: UInt64?
    var rowWithinEntry = 0
    var followsEnd = true
}

@MainActor
struct LogLayout {
    struct Row: Identifiable {
        let id: UInt64
        let text: String
        let start: Int
        let height: Int
    }

    let rows: [Row]
    let height: Int

    init(entries: [SessionLogEntry], width: Int) {
        var rows: [Row] = []
        var start = 0
        for entry in entries {
            let metadata = entry.metadata.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(
                separator: " ")
            let text = terminalSafeText(
                "\(entry.timestamp) [\(entry.level)] \(entry.label): \(entry.message) \(metadata)")
            let height = layoutText(for: text, width: max(1, width)).lines.count
            rows.append(Row(id: entry.id, text: text, start: start, height: height))
            start += height
        }
        self.rows = rows
        height = start
    }

    func offset(for viewport: LogViewport, height: Int) -> Int {
        let end = max(0, self.height - height)
        if viewport.followsEnd { return end }
        guard let row = rows.first(where: { $0.id == viewport.entryID }) else { return 0 }
        return min(end, row.start + min(viewport.rowWithinEntry, row.height - 1))
    }

    func viewport(at offset: Int, height: Int) -> LogViewport {
        let row = rows.last { $0.start <= offset }
        return LogViewport(
            entryID: row?.id, rowWithinEntry: max(0, offset - (row?.start ?? 0)),
            followsEnd: offset >= max(0, self.height - height))
    }
}

struct LogPanel: View {
    let entries: [SessionLogEntry]
    @Binding var viewport: LogViewport

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let height = max(1, geometry.size.height - 1)
            let layout = LogLayout(entries: entries, width: width)
            VStack(alignment: .leading, spacing: 0) {
                Text("Logs · ` or Escape to close").bold().lineLimit(1)
                ScrollView(
                    .vertical,
                    position: Binding(
                        get: { .init(x: 0, y: layout.offset(for: viewport, height: height)) },
                        set: { viewport = layout.viewport(at: $0.y, height: height) }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(layout.rows) { row in
                            Text(row.text).frame(width: width, height: row.height, alignment: .topLeading)
                        }
                        if entries.isEmpty { Text("No session logs") }
                    }
                }
                .scrollIndicators(.never)
            }
        }
    }
}
