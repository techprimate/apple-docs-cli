import Testing

@testable import CLI

@Suite("Type command parsing")
struct TypeCommandParsingTests {
    @Test("accepts a type name and required technology option")
    func parsesTypeNameAndTechnology() throws {
        let command = try TypeCommand.parse([
            "MXHangDiagnostic",
            "--technology", "MetricKit",
        ])

        #expect(command.name == "MXHangDiagnostic")
        #expect(command.technology == "MetricKit")
        #expect(command.json == false)
    }

    @Test("accepts raw JSON output")
    func parsesJSONFlag() throws {
        let command = try TypeCommand.parse([
            "MXHangDiagnostic",
            "--technology", "MetricKit",
            "--json",
        ])

        #expect(command.json)
    }
}
