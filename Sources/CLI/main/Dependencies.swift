import Foundation
import Logging
import SwiftTUIRuntime

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

    static let documentationRepository = DefaultDocumentationRepository(
        logger: Logger(label: "com.techprimate.apple-docs.repository"), dependencies: documentationClient)

    @MainActor
    static func documentationDispatcher(
        logs: SessionLogBuffer?, telemetry: Telemetry
    ) -> DocumentationCommandDispatcher {
        DocumentationCommandDispatcher(
            browser: { entry in
                let signals = try await TerminalSignals()
                defer { signals.close() }
                // Interactive mode allocates its shared log buffer before logging bootstrap.
                let browser = DefaultDocumentationBrowser(
                    repository: documentationRepository, logs: logs!, opener: DefaultExternalURLOpener(),
                    session: TerminalSession(surface: TerminalHost(), input: InputReader(), signals: signals))
                try await browser.run(entry: entry)
            },
            oneShot: OneShotDocumentationRunner(repository: documentationRepository), telemetry: telemetry)
    }
}
