import Foundation

/// Interprets the cursor and erase sequences emitted by Twill's fullscreen presenter.
/// This test fixture uses ASCII content and single-cell border glyphs.
struct BrowserTerminalScreen {
    static func render(_ output: String, columns: Int, rows: Int) -> String {
        let scalars = Array(output.unicodeScalars)
        var cells = Array(repeating: Array(repeating: Character(" "), count: columns), count: rows)
        var row = 0
        var column = 0
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "\u{1B}" {
                guard index + 1 < scalars.count, scalars[index + 1] == "[",
                    let end = scalars[(index + 2)...].firstIndex(where: { ("@"..."~").contains(Character($0)) })
                else { break }
                let sequence = String(String.UnicodeScalarView(scalars[(index + 2)..<end]))
                applyCSI(scalars[end], parameters: sequence, cells: &cells, row: &row, column: &column)
                index = end + 1
                continue
            }
            if scalar == "\r" {
                column = 0
            } else if scalar == "\n" {
                row = min(rows - 1, row + 1)
                column = 0
            } else if cells.indices.contains(row), cells[row].indices.contains(column) {
                cells[row][column] = Character(scalar)
                column += 1
            }
            index += 1
        }
        return cells.map { String($0).trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
    }

    private static func applyCSI(
        _ command: UnicodeScalar, parameters: String, cells: inout [[Character]], row: inout Int, column: inout Int
    ) {
        let value = Int(parameters) ?? 1
        switch command {
        case "H":
            let position = parameters.split(separator: ";").compactMap { Int($0) }
            row = max(0, (position.first ?? 1) - 1)
            column = max(0, (position.count > 1 ? position[1] : 1) - 1)
        case "A": row = max(0, row - value)
        case "B": row = min(cells.count - 1, row + value)
        case "C": column = min(cells[0].count, column + value)
        case "K":
            if parameters == "2", cells.indices.contains(row) {
                cells[row] = Array(repeating: " ", count: cells[0].count)
            }
        case "J":
            if parameters == "2" {
                cells = Array(repeating: Array(repeating: " ", count: cells[0].count), count: cells.count)
            }
        default: break
        }
    }
}
