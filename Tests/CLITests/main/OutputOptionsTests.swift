import Testing

@testable import CLI

@Suite("Noninteractive output options")
struct OutputOptionsTests {
    @Test(
        "selects human text by default and separates audience from format",
        arguments: [
            ([], OutputAudience.human, OutputFormat.text),
            (["--agent"], .agent, .text),
            (["--json"], .human, .json),
            (["--agent", "--json"], .human, .json),
            (["--json", "--agent"], .human, .json),
        ])
    func selectsOutput(flags: [String], audience: OutputAudience, format: OutputFormat) throws {
        // -- Arrange --
        let arguments = ["types", "view", "String", "--technology", "Swift"] + flags

        // -- Act --
        let command = try #require(CLI.parseAsRoot(arguments) as? TypesViewCommand)

        // -- Assert --
        #expect(command.output.audience == audience)
        #expect(command.output.format == format)
    }

}
