import Foundation
import Logging

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct Dependencies: Sendable {
    let terminalCapabilities = DefaultTerminalCapabilities()
    let commandOutputWriter = DefaultCommandOutputWriter()
    let telemetry: DefaultTelemetry
    let httpCache: URLCache?
    let httpDataTransport: URLSession
    let documentationRepository: DefaultAppleDocumentationRepository<DefaultAppleDocumentationClient<URLSession>>

    init(telemetry: DefaultTelemetry) {
        self.telemetry = telemetry
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
        documentationRepository = DefaultAppleDocumentationRepository(
            logger: Logger(label: "com.techprimate.apple-docs.repository"),
            dependencies: DefaultAppleDocumentationClient(
                logger: Logger(label: "com.techprimate.apple-docs.client"), dependencies: httpDataTransport))
    }

    var documentationCache: URLCache? {
        httpDataTransport.configuration.urlCache
    }

    func agentSkillFileManager() -> FileManager {
        .default
    }

    func agentSkillInstallationService() -> DefaultAgentSkillInstallationService {
        DefaultAgentSkillInstallationService(
            logger: Logger(label: "com.techprimate.apple-docs.skills.installer"),
            fileManager: agentSkillFileManager()
        )
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

    func documentationSearchRenderer(output: OutputOptions) -> DefaultDocumentationSearchRenderer {
        DefaultDocumentationSearchRenderer(output: output.format, audience: output.audience)
    }

    func technologyListRenderer(output: OutputOptions) -> DefaultTechnologyListRenderer {
        DefaultTechnologyListRenderer(output: output.json ? .json : .table, audience: output.audience)
    }
}
