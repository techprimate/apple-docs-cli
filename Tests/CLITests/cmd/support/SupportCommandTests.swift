import Foundation
import Testing

@testable import CLI

@Suite("Support CLI commands")
struct SupportCommandTests {
    @Test("registers support commands with independent audience and format", arguments: supportCommandArguments)
    func parsesCommands(arguments: [String]) throws {
        // -- Arrange --
        let arguments = ["--verbose"] + arguments + ["--agent", "--json"]

        // -- Act --
        let command = try #require(CLI.parseAsRoot(arguments) as? any SupportExecutableCommand)

        // -- Assert --
        #expect(command.global.verbose)
        #expect(command.output.agent)
        #expect(command.output.json)
    }

    @Test(
        "requires explicit identifiers for content selection",
        arguments: [
            ["support", "view"], ["support", "guides", "contents"],
            ["support", "glossary", "view"], ["support", "terms", "view"],
        ])
    func requiresIdentifiers(arguments: [String]) {
        // -- Arrange --
        let arguments = arguments

        // -- Act --
        let parse = { try CLI.parseAsRoot(arguments) }

        // -- Assert --
        #expect(throws: (any Error).self) { try parse() }
    }

    @Test("keeps built-in help separate from support content")
    func keepsBuiltInHelp() throws {
        // -- Arrange --
        let arguments = ["help", "support", "guides"]

        // -- Act --
        let command = try CLI.parseAsRoot(arguments)
        let help = CLI.helpMessage()

        // -- Assert --
        #expect(!(command is any SupportExecutableCommand))
        #expect(help.contains("support"))
        #expect(help.contains("--help"))
    }
}

let supportCommandArguments = [
    ["support", "articles", "list", "--category", "membership"],
    ["support", "guides", "list"],
    ["support", "guides", "contents", "--name", "app-store-connect"],
    ["support", "glossary", "list", "--query", "account"],
    ["support", "glossary", "view", "--term", "Account Holder"],
    ["support", "terms", "list", "--category", "guidelines"],
    ["support", "terms", "view", "--name", "app-review-guidelines"],
    ["support", "view", "--path", "support/fee-waiver"],
]
