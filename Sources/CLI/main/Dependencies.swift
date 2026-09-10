import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

enum Dependencies {
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
        dependencies: httpDataTransport
    )

    static func documentationRenderer(
        json: Bool
    ) -> DefaultTypeDocumentationRenderer {
        DefaultTypeDocumentationRenderer(
            output: json ? .json : .text
        )
    }

    static func documentationTypeListRenderer(
        json: Bool
    ) -> DefaultDocumentationTypeListRenderer {
        DefaultDocumentationTypeListRenderer(
            output: json ? .json : .table
        )
    }

    static func technologyListRenderer(
        json: Bool
    ) -> DefaultTechnologyListRenderer {
        DefaultTechnologyListRenderer(
            output: json ? .json : .table
        )
    }
}
