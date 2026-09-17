import Foundation
import Logging

@MainActor
final class BrowserCoordinator {
    private(set) var state: BrowserState
    private(set) var isStopped = false
    var onChange: (@MainActor (BrowserState) -> Void)?

    private let repository: DocumentationRepository
    private let openExternal: @Sendable (URL) async throws -> Void
    private let logger: Logger
    private let pageLoader: BrowserPageLoader
    private var tasks: [UInt64: Task<Void, Never>] = [:]
    private var started = false

    init(
        repository: DocumentationRepository, entry: BrowserEntry,
        openExternal: @escaping @Sendable (URL) async throws -> Void,
        logger: Logger = Logger(label: "apple-docs.browser")
    ) {
        self.repository = repository
        self.openExternal = openExternal
        self.logger = logger
        state = BrowserState(entry: entry)
        pageLoader = BrowserPageLoader(repository: repository, logger: logger)
    }

    func start() {
        guard !started, !isStopped else { return }
        started = true
        send(.start)
    }

    func send(_ action: BrowserAction) {
        guard !isStopped else { return }
        let effects = BrowserReducer.reduce(state: &state, action: action)
        onChange?(state)
        for effect in effects {
            guard !isStopped else { break }
            execute(effect)
        }
        if case .pageLoaded = action, started, let technology = state.technology {
            send(.ensureRoot(technology: technology))
        }
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        let requestIDs = Array(tasks.keys) + pageLoader.activeRequestIDs
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        pageLoader.stop()
        for id in requestIDs { _ = BrowserReducer.reduce(state: &state, action: .operationCancelled(id)) }
        _ = BrowserReducer.reduce(state: &state, action: .quit)
        logger.debug("Stopped documentation browser")
        onChange?(state)
    }

    private func execute(_ effect: BrowserEffect) {
        switch effect {
        case .loadNamedPage, .loadRoot, .loadTypes, .loadTechnologies: executeEntry(effect)
        case .loadPage(let requestID, let destination):
            pageLoader.load(requestID: requestID, destination: destination) { [weak self] result in
                self?.finishPage(result, requestID: requestID, nodeID: nil)
            }
        case .loadChildren(let nodeID, let requestID, let destination):
            pageLoader.load(requestID: requestID, destination: destination) { [weak self] result in
                self?.finishPage(result, requestID: requestID, nodeID: nodeID)
            }
        case .cancelPage(let requestID):
            pageLoader.cancel(requestID: requestID)
            tasks.removeValue(forKey: requestID)?.cancel()
        case .search(let requestID, let technology, let query):
            search(requestID: requestID, technology: technology, query: query)
        case .cancelSearch(let requestID): tasks.removeValue(forKey: requestID)?.cancel()
        case .openExternal(let requestID, let url):
            let opener = openExternal
            perform(
                requestID: requestID, operation: { try await opener(url) },
                completion: { [weak self] result in
                    switch result {
                    case .success: self?.send(.externalOpened(requestID: requestID))
                    case .failure(let error):
                        self?.send(.externalFailed(requestID: requestID, message: error.localizedDescription))
                    }
                })
        case .quit: stop()
        }
    }

    private func finishPage(
        _ result: Result<LoadedDocumentationPage, any Error>, requestID: UInt64, nodeID: NavigatorNodeID?
    ) {
        switch result {
        case .success(let loaded):
            if let nodeID {
                send(.childrenLoaded(nodeID: nodeID, requestID: requestID, page: loaded.page))
            } else {
                send(.pageLoaded(requestID: requestID, page: loaded))
            }
        case .failure(let error):
            if isCancellation(error) {
                send(.operationCancelled(requestID))
                return
            }
            logger.warning("Browser page request failed", metadata: ["request_id": .stringConvertible(requestID)])
            if let nodeID {
                send(.childrenFailed(nodeID: nodeID, requestID: requestID, message: error.localizedDescription))
            } else {
                send(.pageFailed(requestID: requestID, message: error.localizedDescription))
            }
        }
    }

    private func search(requestID: UInt64, technology: String, query: String) {
        let repository = repository
        let metadata: Logger.Metadata = [
            "request_id": .stringConvertible(requestID), "apple_docs.technology": .string(technology),
        ]
        logger.debug("Started browser search", metadata: metadata)
        tasks[requestID] = Task { [weak self] in
            let result: Result<DocumentationSearchResult, any Error>
            do { result = .success(try await repository.search(query: query, technology: technology)) } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled, let self, !isStopped, tasks.removeValue(forKey: requestID) != nil else { return }
            switch result {
            case .success(let result):
                logger.debug(
                    "Completed browser search",
                    metadata: metadata.merging([
                        "results": .stringConvertible(result.types.count),
                        "unavailable": .stringConvertible(result.unavailableCollectionPaths.count),
                    ]) { _, new in new })
                send(.searchLoaded(requestID: requestID, technology: technology, result: result))
            case .failure(let error):
                if isCancellation(error) {
                    send(.operationCancelled(requestID))
                    return
                }
                logger.warning("Browser search failed", metadata: metadata)
                send(.searchFailed(requestID: requestID, technology: technology, message: error.localizedDescription))
            }
        }
    }

    private func perform<Value: Sendable>(
        requestID: UInt64, operation: @escaping @Sendable () async throws -> Value,
        completion: @escaping @MainActor (Result<Value, any Error>) -> Void
    ) {
        logger.debug("Started browser entry request", metadata: ["request_id": .stringConvertible(requestID)])
        tasks[requestID] = Task { [weak self] in
            let result: Result<Value, any Error>
            do { result = .success(try await operation()) } catch { result = .failure(error) }
            guard !Task.isCancelled, let self, !isStopped, tasks.removeValue(forKey: requestID) != nil else { return }
            if case .failure(let error) = result, isCancellation(error) {
                send(.operationCancelled(requestID))
                return
            }
            completion(result)
        }
    }

    private func executeEntry(_ effect: BrowserEffect) {
        let repository = repository
        switch effect {
        case .loadNamedPage(let id, let name, let technology):
            perform(
                requestID: id, operation: { try await repository.type(named: name, technology: technology) },
                completion: { [weak self] result in
                    if case .success(let loaded) = result { self?.pageLoader.remember(loaded) }
                    self?.finishPage(result, requestID: id, nodeID: nil)
                })
        case .loadRoot(let id, let technology):
            let destination = DocumentationDestination(
                technology: technology.lowercased(), path: "/documentation/" + technology.lowercased())
            pageLoader.load(
                requestID: id, destination: destination, fetch: { try await repository.root(technology: technology) },
                completion: { [weak self] result in
                    switch result {
                    case .success(let loaded):
                        self?.send(.rootLoaded(requestID: id, technology: technology, page: loaded))
                    case .failure(let error):
                        if self?.isCancellation(error) == true {
                            self?.send(.operationCancelled(id))
                        } else {
                            self?.send(
                                .rootFailed(requestID: id, technology: technology, message: error.localizedDescription))
                        }
                    }
                })
        case .loadTypes, .loadTechnologies: executeCatalog(effect)
        default: break
        }
    }

    private func executeCatalog(_ effect: BrowserEffect) {
        let repository = repository
        switch effect {
        case .loadTypes(let id, let technology):
            perform(
                requestID: id, operation: { try await repository.types(technology: technology) },
                completion: { [weak self] result in
                    switch result {
                    case .success(let types):
                        self?.send(.typesLoaded(requestID: id, technology: technology, types: types))
                    case .failure(let error):
                        self?.send(
                            .typesFailed(requestID: id, technology: technology, message: error.localizedDescription))
                    }
                })
        case .loadTechnologies(let id):
            perform(
                requestID: id, operation: { try await repository.technologies() },
                completion: { [weak self] result in
                    switch result {
                    case .success(let technologies):
                        self?.send(.technologiesLoaded(requestID: id, technologies: technologies))
                    case .failure(let error):
                        self?.send(.technologiesFailed(requestID: id, message: error.localizedDescription))
                    }
                })
        default: break
        }
    }

    private func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}
