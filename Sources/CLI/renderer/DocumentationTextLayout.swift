struct DocumentationTextLayout: Sendable {
    private let width = 80

    func heading(_ title: String, prominent: Bool = false) -> String {
        title + "\n" + String(repeating: prominent ? "━" : "─", count: min(title.count, width))
    }

    func paragraph(_ text: String, indent: String = "  ", firstPrefix: String? = nil) -> String {
        var lines: [String] = []
        var prefix = firstPrefix ?? indent
        var line = ""
        for word in text.split(whereSeparator: \.isWhitespace) {
            if !line.isEmpty && prefix.count + line.count + 1 + word.count > width {
                lines.append(prefix + line)
                prefix = indent
                line = ""
            }
            if !line.isEmpty {
                line += " "
            }
            line += word
        }
        if !line.isEmpty {
            lines.append(prefix + line)
        }
        return lines.joined(separator: "\n")
    }

    func codeBlock(_ lines: [String], language: String?, indent: String = "  ") -> String {
        guard !lines.isEmpty else { return "" }
        let label = language.map { $0 == "swift" ? "Swift" : $0 } ?? "Code"
        let top = "─ \(label) "
        let width = max(top.count, (lines.map(\.count).max() ?? 0) + 2)
        let rows = lines.map { line in
            indent + "│ " + line + String(repeating: " ", count: width - line.count - 1) + "│"
        }
        return
            ([indent + "╭" + top + String(repeating: "─", count: width - top.count) + "╮"]
            + rows + [indent + "╰" + String(repeating: "─", count: width) + "╯"])
            .joined(separator: "\n")
    }

    func table(_ rows: [(String, String)]) -> String {
        guard !rows.isEmpty else { return "" }
        let keyWidth = rows.map { $0.0.count }.max() ?? 0
        let valueWidth = rows.map { $0.1.count }.max() ?? 0
        let keyRule = String(repeating: "─", count: keyWidth + 2)
        let valueRule = String(repeating: "─", count: valueWidth + 2)
        let body = rows.map { key, value in
            "  │ " + key + String(repeating: " ", count: keyWidth - key.count)
                + " │ " + value + String(repeating: " ", count: valueWidth - value.count) + " │"
        }
        return (["  ╭\(keyRule)┬\(valueRule)╮"] + body + ["  ╰\(keyRule)┴\(valueRule)╯"])
            .joined(separator: "\n")
    }
}
