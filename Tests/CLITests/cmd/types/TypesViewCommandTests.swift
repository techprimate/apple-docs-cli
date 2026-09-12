import Testing

@testable import CLI

@Suite("Types command parsing")
struct TypesViewCommandTests {
    @Test(
        "accepts JSON and agent output for types list",
        arguments: [
            ["--json"], ["--agent"], ["--json", "--agent"], ["--agent", "--json"],
        ])
    func parsesTypesList(flags: [String]) throws {
        // -- Arrange --
        let arguments =
            [
                "types", "list",
                "--technology", "MetricKit",
            ] + flags

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        let listCommand = try #require(command as? TypesListCommand)
        #expect(listCommand.technology == "MetricKit")
        #expect(listCommand.json)
    }

    @Test(
        "accepts JSON and agent output for types search",
        arguments: [
            ["--json"], ["--agent"], ["--json", "--agent"], ["--agent", "--json"],
        ])
    func parsesTypesSearch(flags: [String]) throws {
        // -- Arrange --
        let arguments =
            [
                "types", "search", "Button",
                "--technology", "SwiftUI",
            ] + flags

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        let searchCommand = try #require(command as? TypesSearchCommand)
        #expect(searchCommand.query == "Button")
        #expect(searchCommand.technology == "SwiftUI")
        #expect(searchCommand.json)
    }

    @Test("accepts a type name and required technology option")
    func parsesTypeNameAndTechnology() throws {
        // -- Arrange --
        let arguments = [
            "types", "view", "MXHangDiagnostic",
            "--technology", "MetricKit",
        ]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        let viewCommand = try #require(command as? TypesViewCommand)
        #expect(viewCommand.name == "MXHangDiagnostic")
        #expect(viewCommand.technology == "MetricKit")
        #expect(viewCommand.json == false)
    }

    @Test(
        "accepts JSON and agent output for types view",
        arguments: [
            ["--json"], ["--agent"], ["--json", "--agent"], ["--agent", "--json"],
        ])
    func parsesJSONFlag(flags: [String]) throws {
        // -- Arrange --
        let arguments =
            [
                "types", "view", "MXHangDiagnostic",
                "--technology", "MetricKit",
            ] + flags

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        let viewCommand = try #require(command as? TypesViewCommand)
        #expect(viewCommand.json)
    }
}
