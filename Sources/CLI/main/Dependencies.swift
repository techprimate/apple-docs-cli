import Foundation
import Logging

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

enum Dependencies {
    static let telemetry = DefaultTelemetry(
        // Telemetry starts before SwiftLog is bootstrapped. Resolve its logger only when logging an event.
        logger: { Logger(label: "com.techprimate.apple-docs.telemetry") },
        environment: ProcessInfo.processInfo.environment
    )

    static let httpCache: URLCache? = {
        guard
            let cachesDirectory = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first
        else {
            return nil
        }
        let cacheDirectory = cachesDirectory.appendingPathComponent(
            "com.techprimate.apple-docs",
            isDirectory: true
        )
        #if canImport(FoundationNetworking)
            return URLCache(
                memoryCapacity: 16_000_000,
                diskCapacity: 1_000_000_000,
                diskPath: cacheDirectory.path
            )
        #else
            return URLCache(
                memoryCapacity: 16_000_000,
                diskCapacity: 1_000_000_000,
                directory: cacheDirectory
            )
        #endif
    }()

    static let httpDataTransport: URLSession = {
        let configuration = URLSessionConfiguration.default
        if let httpCache {
            configuration.urlCache = httpCache
        }
        return URLSession(configuration: configuration)
    }()

    static var documentationCache: URLCache? {
        httpDataTransport.configuration.urlCache
    }

    static let documentationClient = DefaultAppleDocumentationClient(
        logger: Logger(label: "com.techprimate.apple-docs.client"),
        dependencies: httpDataTransport
    )

    static func agentSkillInstaller() -> AgentSkillInstaller {
        AgentSkillInstaller(logger: Logger(label: "com.techprimate.apple-docs.skills.installer"))
    }

    static func documentationRenderer(output: OutputOptions) -> DefaultTypeDocumentationRenderer {
        DefaultTypeDocumentationRenderer(output: output.format, audience: output.audience)
    }

    static func documentationTypeListRenderer(
        output: OutputOptions, technology: String
    ) -> DefaultDocumentationTypeListRenderer {
        DefaultDocumentationTypeListRenderer(
            output: output.json ? .json : .table, audience: output.audience, technology: technology)
    }

    static func technologyListRenderer(output: OutputOptions) -> DefaultTechnologyListRenderer {
        DefaultTechnologyListRenderer(output: output.json ? .json : .table, audience: output.audience)
    }
}
