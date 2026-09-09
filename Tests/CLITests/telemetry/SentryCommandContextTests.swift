import Testing

@testable import CLI

@Suite("Sentry command context")
struct SentryCommandContextTests {
    @Test("opts documentation identifiers into types view telemetry")
    func includesTypesViewIdentifiers() {
        // -- Arrange --
        let expectedKeys = [
            "apple_docs.technology",
            "apple_docs.type",
            "cli.command",
            "cli.output_json",
        ]

        // -- Act --
        let context = SentryCommandContext.typesView(
            name: "MXHangDiagnostic",
            technology: "MetricKit",
            json: true
        )

        // -- Assert --
        #expect(context.command == "types.view")
        #expect(context.typeName == "MXHangDiagnostic")
        #expect(context.technology == "MetricKit")
        #expect(context.outputJSON == true)
        #expect(context.attributes.keys.sorted() == expectedKeys)
        #expect(context.metricAttributes.keys.sorted() == expectedKeys.dropLast())
        #expect(context.logMetadata.keys.sorted() == expectedKeys)
    }

    @Test("opts technology and output mode into types list telemetry")
    func includesTypesListContext() {
        // -- Arrange --
        let expectedKeys = [
            "apple_docs.technology",
            "cli.command",
            "cli.output_json",
        ]

        // -- Act --
        let context = SentryCommandContext.typesList(
            technology: "SwiftData",
            json: true
        )

        // -- Assert --
        #expect(context.command == "types.list")
        #expect(context.typeName == nil)
        #expect(context.technology == "SwiftData")
        #expect(context.outputJSON == true)
        #expect(context.attributes.keys.sorted() == expectedKeys)
        #expect(context.metricAttributes.keys.sorted() == expectedKeys.dropLast())
        #expect(context.logMetadata.keys.sorted() == expectedKeys)
    }

    @Test("excludes the skill name from agent command telemetry")
    func excludesAgentSkillName() {
        // -- Arrange --
        let expectedKeys = ["cli.command"]

        // -- Act --
        let context = SentryCommandContext.agentSkillsGet

        // -- Assert --
        #expect(context.command == "agent.skills.get")
        #expect(context.typeName == nil)
        #expect(context.technology == nil)
        #expect(context.outputJSON == nil)
        #expect(context.attributes.keys.sorted() == expectedKeys)
        #expect(context.metricAttributes.keys.sorted() == expectedKeys)
        #expect(context.logMetadata.keys.sorted() == expectedKeys)
    }

    @Test("opts only output mode into technologies list telemetry")
    func includesTechnologiesListOutputMode() {
        // -- Arrange --
        let expectedAttributeKeys = ["cli.command", "cli.output_json"]

        // -- Act --
        let context = SentryCommandContext.technologiesList(json: false)

        // -- Assert --
        #expect(context.command == "technologies.list")
        #expect(context.typeName == nil)
        #expect(context.technology == nil)
        #expect(context.outputJSON == false)
        #expect(context.attributes.keys.sorted() == expectedAttributeKeys)
        #expect(context.metricAttributes.keys.sorted() == ["cli.command"])
        #expect(context.logMetadata.keys.sorted() == expectedAttributeKeys)
    }
}
