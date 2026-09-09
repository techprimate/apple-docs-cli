import Testing

@testable import CLI

@Suite("Types command parsing")
struct TypesViewCommandTests {
    @Test("accepts the types list command with a required technology")
    func parsesTypesList() throws {
        // -- Arrange --
        let arguments = [
            "types", "list",
            "--technology", "MetricKit",
            "--json",
        ]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        let listCommand = try #require(command as? TypesListCommand)
        #expect(listCommand.technology == "MetricKit")
        #expect(listCommand.json)
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

    @Test("accepts raw JSON output")
    func parsesJSONFlag() throws {
        // -- Arrange --
        let arguments = [
            "types", "view", "MXHangDiagnostic",
            "--technology", "MetricKit",
            "--json",
        ]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)

        // -- Assert --
        let viewCommand = try #require(command as? TypesViewCommand)
        #expect(viewCommand.json)
    }
}
