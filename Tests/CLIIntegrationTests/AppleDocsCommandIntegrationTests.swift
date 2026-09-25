import Foundation
import Testing

private let integrationTestsEnabled =
    ProcessInfo.processInfo.environment["APPLE_DOCS_EXECUTABLE"] != nil

@Suite(
    "CLI integration",
    .enabled(if: integrationTestsEnabled, "Run with make test-integration."),
    .serialized
)
struct AppleDocsCommandIntegrationTests {
    @Test("returns Swift String documentation as JSON", arguments: [["--json"], ["--agent", "--json"]])
    func returnsSwiftStringJSON(flags: [String]) throws {
        // -- Arrange --
        let arguments = ["types", "view", "String", "--technology", "Swift"] + flags

        // -- Act --
        let output = try runAppleDocs(arguments)
        let document = try JSONDecoder().decode(TypeDocument.self, from: Data(output.utf8))

        // -- Assert --
        #expect(document.title == "String")
        #expect(document.modules == ["Swift"])
        #expect(document.kind == "struct")
    }

    @Test(
        "agent output is Markdown with supported follow-up commands",
        arguments: [
            (["types", "view", "String", "--technology", "Swift"], "# String"),
            (["types", "list", "--technology", "MetricKit"], "# Symbols"),
            (["types", "search", "Button", "--technology", "SwiftUI"], "# Symbols"),
            (["technologies", "list"], "# Technologies"),
        ])
    func rendersAgentMarkdown(arguments: [String], heading: String) throws {
        // -- Arrange --
        let arguments = arguments + ["--agent"]

        // -- Act --
        let output = try runAppleDocs(arguments)

        // -- Assert --
        #expect(output.hasPrefix(heading + "\n"))
        #expect(output.contains("--agent"))
        #expect(!output.contains("\u{1B}"))
    }

    @Test("agent JSON includes navigation without verbose diagnostics on stdout")
    func rendersAgentJSON() throws {
        // -- Arrange --
        let arguments = ["types", "view", "String", "--technology", "Swift", "--agent", "--json", "--verbose"]
        var diagnostics = ""

        // -- Act --
        let output = try runAppleDocs(arguments, captureStandardError: { diagnostics = $0 })
        let value = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])

        // -- Assert --
        #expect(value["title"] as? String == "String")
        #expect(value["navigation"] != nil)
        #expect(value["metadata"] == nil)
        #expect(!output.contains("\u{1B}"))
        #expect(diagnostics.contains("debug"))
    }

    @Test("returns Foundation URL documentation as JSON")
    func returnsFoundationURLJSON() throws {
        // -- Arrange --
        let arguments = ["types", "view", "URL", "--technology", "Foundation", "--json"]

        // -- Act --
        let output = try runAppleDocs(arguments)
        let document = try JSONDecoder().decode(TypeDocument.self, from: Data(output.utf8))

        // -- Assert --
        #expect(document.title == "URL")
        #expect(document.modules == ["Foundation"])
        #expect(document.kind == "struct")
    }

    @Test("renders Swift String documentation as text")
    func rendersSwiftStringText() throws {
        // -- Arrange --
        let arguments = ["types", "view", "String", "--technology", "Swift"]

        // -- Act --
        let output = try runAppleDocs(arguments)

        // -- Assert --
        #expect(output.hasPrefix("String\n━━━━━━\nStructure · Swift\nSymbol kind: struct\n"))
        #expect(output.contains("Declaration\n───────────"))
        #expect(output.contains("│ @frozen struct String"))
        #expect(output.contains("Overview\n────────"))
    }

    @Test("lists MetricKit root types as JSON", arguments: [["--json"], ["--agent", "--json"]])
    func listsMetricKitTypes(flags: [String]) throws {
        // -- Arrange --
        let arguments = ["types", "list", "--technology", "MetricKit"] + flags

        // -- Act --
        let output = try runAppleDocs(arguments)
        let types = try JSONDecoder().decode([ListedType].self, from: Data(output.utf8))

        // -- Assert --
        #expect(
            types.contains(
                ListedType(
                    kind: "class",
                    name: "MetricManager",
                    path: "metricmanager",
                    url: "https://developer.apple.com/documentation/metrickit/metricmanager"
                )
            )
        )
    }

    @Test("searches SwiftUI collection groups as JSON", arguments: [["--json"], ["--agent", "--json"]])
    func searchesSwiftUITypes(flags: [String]) throws {
        // -- Arrange --
        let arguments =
            [
                "types", "search", "Button",
                "--technology", "SwiftUI",
            ] + flags

        // -- Act --
        let output = try runAppleDocs(arguments)
        let types = try JSONDecoder().decode([ListedType].self, from: Data(output.utf8))

        // -- Assert --
        #expect(
            types.contains(
                ListedType(
                    kind: "struct",
                    name: "Button",
                    path: "button",
                    url: "https://developer.apple.com/documentation/swiftui/button"
                )
            )
        )
    }

    @Test("resolves a dotted nested type as JSON")
    func resolvesDottedNestedType() throws {
        // -- Arrange --
        let arguments = [
            "types", "view", "URLSession.AsyncBytes",
            "--technology", "Foundation",
            "--json",
        ]

        // -- Act --
        let output = try runAppleDocs(arguments)
        let document = try JSONDecoder().decode(TypeDocument.self, from: Data(output.utf8))

        // -- Assert --
        #expect(document.title == "URLSession.AsyncBytes")
    }

    @Test("lists stable technologies as JSON", arguments: [["--json"], ["--agent", "--json"]])
    func listsStableTechnologies(flags: [String]) throws {
        // -- Arrange --
        let arguments = ["technologies", "list"] + flags

        // -- Act --
        let output = try runAppleDocs(arguments)
        let technologies = try JSONDecoder().decode([Technology].self, from: Data(output.utf8))

        // -- Assert --
        #expect(
            technologies.contains(
                Technology(
                    identifier: "doc://com.apple.documentation/documentation/Foundation",
                    name: "Foundation"
                )
            )
        )
        #expect(
            technologies.contains(
                Technology(
                    identifier: "doc://com.apple.documentation/documentation/Swift",
                    name: "Swift"
                )
            )
        )
    }
}

private struct TypeDocument: Decodable {
    let modules: [String]
    let kind: String
    let title: String
}

private struct ListedType: Decodable, Equatable {
    let kind: String
    let name: String
    let path: String
    let url: String
}

private struct Technology: Decodable, Equatable {
    let identifier: String
    let name: String
}
