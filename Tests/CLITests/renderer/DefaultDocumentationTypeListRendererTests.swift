import Testing

@testable import CLI

@Suite("Default documentation type list renderer")
struct DefaultDocumentationTypeListRendererTests {
    @Test("renders documentation types as a table")
    func rendersTable() throws {
        // -- Arrange --
        let types = [
            DocumentationType(
                name: "Model()",
                kind: "macro",
                path: "model()",
                url: "https://developer.apple.com/documentation/swiftdata/model()"
            )
        ]
        let renderer = DefaultDocumentationTypeListRenderer(output: .table)

        // -- Act --
        let output = try renderer.render(types)

        // -- Assert --
        #expect(
            output == """
                SYMBOL   KIND   PATH     URL
                Model()  macro  model()  https://developer.apple.com/documentation/swiftdata/model()
                """
        )
    }

    @Test("renders documentation types as JSON")
    func rendersJSON() throws {
        // -- Arrange --
        let types = [
            DocumentationType(
                name: "Model()",
                kind: "macro",
                path: "model()",
                url: "https://developer.apple.com/documentation/swiftdata/model()"
            )
        ]
        let renderer = DefaultDocumentationTypeListRenderer(output: .json)

        // -- Act --
        let output = try renderer.render(types)

        // -- Assert --
        #expect(
            output == """
                [
                  {
                    "kind" : "macro",
                    "name" : "Model()",
                    "path" : "model()",
                    "url" : "https://developer.apple.com/documentation/swiftdata/model()"
                  }
                ]
                """
        )
    }
}
