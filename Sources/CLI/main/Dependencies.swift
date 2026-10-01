import Foundation
import Logging

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct Dependencies: Sendable {
    static let shared = Dependencies()

    let terminalCapabilities = DefaultTerminalCapabilities()
    let terminalSetup = TerminalSetup()
    let logBuffer = LogBuffer()
    let telemetry = DefaultTelemetry(
        // Telemetry starts before SwiftLog is bootstrapped. Resolve its logger only when logging an event.
        logger: { Logger(label: "com.techprimate.apple-docs.telemetry") },
        environment: ProcessInfo.processInfo.environment
    )
    let httpCache: URLCache?
    let httpDataTransport: URLSession
    var documentationClient: DefaultAppleDocumentationClient<URLSession> {
        DefaultAppleDocumentationClient(
            logger: Logger(label: "com.techprimate.apple-docs.client"), dependencies: httpDataTransport)
    }

    init() {
        if let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cacheDirectory = cachesDirectory.appendingPathComponent("com.techprimate.apple-docs", isDirectory: true)
            #if canImport(FoundationNetworking)
                httpCache = URLCache(
                    memoryCapacity: 16_000_000, diskCapacity: 1_000_000_000, diskPath: cacheDirectory.path)
            #else
                httpCache = URLCache(
                    memoryCapacity: 16_000_000, diskCapacity: 1_000_000_000, directory: cacheDirectory)
            #endif
        } else {
            httpCache = nil
        }

        let configuration = URLSessionConfiguration.default
        if let httpCache {
            configuration.urlCache = httpCache
        }
        httpDataTransport = URLSession(configuration: configuration)
    }

    var documentationCache: URLCache? {
        httpDataTransport.configuration.urlCache
    }

    func agentSkillFileManager() -> FileManager {
        .default
    }

    func agentSkillInstaller() -> AgentSkillInstaller {
        AgentSkillInstaller(logger: Logger(label: "com.techprimate.apple-docs.skills.installer"))
    }

    func documentationRenderer(output: OutputOptions) -> DefaultTypeDocumentationRenderer {
        DefaultTypeDocumentationRenderer(output: output.format, audience: output.audience)
    }

    func documentationTypeListRenderer(
        output: OutputOptions, technology: String
    ) -> DefaultDocumentationTypeListRenderer {
        DefaultDocumentationTypeListRenderer(
            output: output.json ? .json : .table, audience: output.audience, technology: technology)
    }

    func technologyListRenderer(output: OutputOptions) -> DefaultTechnologyListRenderer {
        DefaultTechnologyListRenderer(output: output.json ? .json : .table, audience: output.audience)
    }
}
