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
    @Test("returns Swift String documentation as JSON", arguments: ["--json", "--agent"])
    func returnsSwiftStringJSON(flag: String) throws {
        // -- Arrange --
        let arguments = ["types", "view", "String", "--technology", "Swift", flag]

        // -- Act --
        let output = try runAppleDocs(arguments)
        let document = try JSONDecoder().decode(TypeDocument.self, from: Data(output.utf8))

        // -- Assert --
        #expect(document.metadata.title == "String")
        #expect(document.metadata.modules.map(\.name) == ["Swift"])
        #expect(document.metadata.symbolKind == "struct")
    }

    @Test("returns Foundation URL documentation as JSON")
    func returnsFoundationURLJSON() throws {
        // -- Arrange --
        let arguments = ["types", "view", "URL", "--technology", "Foundation", "--json"]

        // -- Act --
        let output = try runAppleDocs(arguments)
        let document = try JSONDecoder().decode(TypeDocument.self, from: Data(output.utf8))

        // -- Assert --
        #expect(document.metadata.title == "URL")
        #expect(document.metadata.modules.map(\.name) == ["Foundation"])
        #expect(document.metadata.symbolKind == "struct")
    }

    @Test("renders Swift String documentation as text")
    func rendersSwiftStringText() throws {
        // -- Arrange --
        let arguments = ["types", "view", "String", "--technology", "Swift"]

        // -- Act --
        let output = try runAppleDocs(arguments)

        // -- Assert --
        #expect(output.hasPrefix("String\n━━━━━━\nStructure · Swift\n"))
        #expect(output.contains("Declaration\n───────────"))
        #expect(output.contains("│ @frozen struct String"))
        #expect(output.contains("Overview\n────────"))
    }

    @Test("lists MetricKit root types as JSON", arguments: ["--json", "--agent"])
    func listsMetricKitTypes(flag: String) throws {
        // -- Arrange --
        let arguments = ["types", "list", "--technology", "MetricKit", flag]

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

    @Test("searches SwiftUI collection groups as JSON", arguments: ["--json", "--agent"])
    func searchesSwiftUITypes(flag: String) throws {
        // -- Arrange --
        let arguments = [
            "types", "search", "Button",
            "--technology", "SwiftUI",
            flag,
        ]

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
        #expect(document.metadata.title == "URLSession.AsyncBytes")
    }

    @Test("lists stable technologies as JSON", arguments: ["--json", "--agent"])
    func listsStableTechnologies(flag: String) throws {
        // -- Arrange --
        let arguments = ["technologies", "list", flag]

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
    let metadata: Metadata

    struct Metadata: Decodable {
        let modules: [Module]
        let symbolKind: String
        let title: String
    }

    struct Module: Decodable {
        let name: String
    }
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
