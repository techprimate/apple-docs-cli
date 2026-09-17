import Logging

@MainActor
final class BrowserPageLoader {
    typealias Completion = @MainActor (Result<LoadedDocumentationPage, any Error>) -> Void

    private struct Request {
        let generation: UInt64
        let task: Task<Void, Never>
        var consumers: [UInt64: Completion]
    }

    private let repository: DocumentationRepository
    private let logger: Logger
    private var pages: [DocumentationDestination: LoadedDocumentationPage] = [:]
    private var requests: [DocumentationDestination: Request] = [:]
    private var generation: UInt64 = 0

    init(repository: DocumentationRepository, logger: Logger) {
        self.repository = repository
        self.logger = logger
    }

    var activeRequestIDs: [UInt64] { requests.values.flatMap { $0.consumers.keys } }

    func load(
        requestID: UInt64, destination: DocumentationDestination,
        fetch: (@Sendable () async throws -> LoadedDocumentationPage)? = nil,
        completion: @escaping Completion
    ) {
        var key = destination
        key.fragment = nil
        let metadata: Logger.Metadata = ["path": .string(key.path), "request_id": .stringConvertible(requestID)]
        if let page = pages[key] {
            logger.debug("Browser page cache hit", metadata: metadata)
            completion(.success(page))
            return
        }
        if requests[key] != nil {
            requests[key]?.consumers[requestID] = completion
            logger.debug("Joined browser page request", metadata: metadata)
            return
        }
        generation += 1
        let identity = generation
        let fetch = fetch ?? { [repository, key] in try await repository.page(at: key) }
        logger.debug("Started browser page request", metadata: metadata)
        let task = Task { [weak self, key] in
            let result: Result<LoadedDocumentationPage, any Error>
            do { result = .success(try await fetch()) } catch { result = .failure(error) }
            guard !Task.isCancelled else { return }
            self?.complete(key, generation: identity, result: result)
        }
        requests[key] = Request(generation: identity, task: task, consumers: [requestID: completion])
    }

    func cancel(requestID: UInt64) {
        guard let key = requests.first(where: { $0.value.consumers[requestID] != nil })?.key else { return }
        requests[key]?.consumers.removeValue(forKey: requestID)
        if requests[key]?.consumers.isEmpty == true {
            requests.removeValue(forKey: key)?.task.cancel()
            logger.debug("Cancelled unowned browser page request", metadata: ["path": .string(key.path)])
        }
    }

    func remember(_ loaded: LoadedDocumentationPage) {
        var key = loaded.page.destination
        key.fragment = nil
        pages[key] = loaded
    }

    func stop() {
        for request in requests.values { request.task.cancel() }
        requests.removeAll()
        pages.removeAll()
    }

    private func complete(
        _ key: DocumentationDestination, generation: UInt64, result: Result<LoadedDocumentationPage, any Error>
    ) {
        guard let request = requests[key], request.generation == generation else { return }
        requests.removeValue(forKey: key)
        if case .success(let loaded) = result {
            pages[key] = loaded
            remember(loaded)
            logger.debug("Completed browser page request", metadata: ["path": .string(key.path)])
        }
        for id in request.consumers.keys.sorted() { request.consumers[id]?(result) }
    }
}
