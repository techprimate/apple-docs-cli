import Logging
@preconcurrency import SentrySwift

struct SentryCommandContext: Equatable, Sendable {
    let command: String
    let outputJSON: Bool?
    let technology: String?
    let typeName: String?

    static let cacheClean = SentryCommandContext(
        command: "cache.clean",
        outputJSON: nil,
        technology: nil,
        typeName: nil
    )
    static let agentSkillsGet = SentryCommandContext(
        command: "agent.skills.get",
        outputJSON: nil,
        technology: nil,
        typeName: nil
    )
    static let agentSkillsList = SentryCommandContext(
        command: "agent.skills.list",
        outputJSON: nil,
        technology: nil,
        typeName: nil
    )

    static func technologiesList(json: Bool) -> SentryCommandContext {
        SentryCommandContext(
            command: "technologies.list",
            outputJSON: json,
            technology: nil,
            typeName: nil
        )
    }

    static func typesList(
        technology: String,
        json: Bool
    ) -> SentryCommandContext {
        SentryCommandContext(
            command: "types.list",
            outputJSON: json,
            technology: technology,
            typeName: nil
        )
    }

    static func typesSearch(
        technology: String,
        json: Bool
    ) -> SentryCommandContext {
        SentryCommandContext(
            command: "types.search",
            outputJSON: json,
            technology: technology,
            typeName: nil
        )
    }

    static func typesView(
        name: String,
        technology: String,
        json: Bool
    ) -> SentryCommandContext {
        SentryCommandContext(
            command: "types.view",
            outputJSON: json,
            technology: technology,
            typeName: name
        )
    }

    var transactionName: String {
        "apple-docs \(command)"
    }

    var attributes: [String: Any] {
        var attributes: [String: Any] = ["cli.command": command]
        if let outputJSON {
            attributes["cli.output_json"] = outputJSON
        }
        if let technology {
            attributes["apple_docs.technology"] = technology
        }
        if let typeName {
            attributes["apple_docs.type"] = typeName
        }
        return attributes
    }

    var logMetadata: Logger.Metadata {
        var metadata: Logger.Metadata = ["cli.command": .string(command)]
        if let outputJSON {
            metadata["cli.output_json"] = .stringConvertible(outputJSON)
        }
        if let technology {
            metadata["apple_docs.technology"] = .string(technology)
        }
        if let typeName {
            metadata["apple_docs.type"] = .string(typeName)
        }
        return metadata
    }

    var metricAttributes: [String: any SentryAttributeValue] {
        var attributes: [String: any SentryAttributeValue] = [
            "cli.command": command
        ]
        if let technology {
            attributes["apple_docs.technology"] = technology
        }
        if let typeName {
            attributes["apple_docs.type"] = typeName
        }
        return attributes
    }
}
