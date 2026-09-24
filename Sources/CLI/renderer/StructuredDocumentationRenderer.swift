import Foundation

struct StructuredDocumentationRenderer: Sendable {
    func render(_ presentation: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        // JSONEncoder guarantees UTF-8, so this conversion cannot fail.
        return String(data: try encoder.encode(presentation), encoding: .utf8)!
    }
}
