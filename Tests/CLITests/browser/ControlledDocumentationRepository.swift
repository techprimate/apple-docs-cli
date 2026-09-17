import Foundation

@testable import CLI

actor ControlledDocumentationRepository: DocumentationRepository {
    enum Request: Hashable, Sendable {
        case page(DocumentationDestination)
        case named(String, String)
        case root(String)
        case types(String)
        case technologies
        case search(String, String)
    }

    enum Response: Sendable {
        case page(LoadedDocumentationPage)
        case types([DocumentationType])
        case technologies([Technology])
        case search(DocumentationSearchResult)
    }

    enum Failure: Error { case unexpectedResponse }

    private let respondsToCancellation: Bool
    private let changes = AsyncStream<Void>.makeStream()
    private var pending: [Int: CheckedContinuation<Response, any Error>] = [:]
    private(set) var requests: [Request] = []
    private(set) var cancelled: Set<Int> = []

    init(respondsToCancellation: Bool = true) {
        self.respondsToCancellation = respondsToCancellation
    }

    func type(named name: String, technology: String) async throws -> LoadedDocumentationPage {
        guard case .page(let page) = try await request(.named(name, technology)) else {
            throw Failure.unexpectedResponse
        }
        return page
    }

    func page(at destination: DocumentationDestination) async throws -> LoadedDocumentationPage {
        guard case .page(let page) = try await request(.page(destination)) else { throw Failure.unexpectedResponse }
        return page
    }

    func root(technology: String) async throws -> LoadedDocumentationPage {
        guard case .page(let page) = try await request(.root(technology)) else { throw Failure.unexpectedResponse }
        return page
    }

    func types(technology: String) async throws -> [DocumentationType] {
        guard case .types(let types) = try await request(.types(technology)) else { throw Failure.unexpectedResponse }
        return types
    }

    func technologies() async throws -> [Technology] {
        guard case .technologies(let technologies) = try await request(.technologies) else {
            throw Failure.unexpectedResponse
        }
        return technologies
    }

    func search(query: String, technology: String) async throws -> DocumentationSearchResult {
        guard case .search(let result) = try await request(.search(query, technology)) else {
            throw Failure.unexpectedResponse
        }
        return result
    }

    func waitForRequest(_ request: Request, occurrence: Int = 1) async throws -> Int {
        var iterator = changes.stream.makeAsyncIterator()
        while true {
            let matches = requests.indices.filter { requests[$0] == request }
            if matches.count >= occurrence { return matches[occurrence - 1] }
            guard await iterator.next() != nil else { throw CancellationError() }
        }
    }

    func waitForCancellation(_ id: Int) async throws {
        var iterator = changes.stream.makeAsyncIterator()
        while !cancelled.contains(id) {
            guard await iterator.next() != nil else { throw CancellationError() }
        }
    }

    func complete(_ id: Int, with response: Response) {
        pending.removeValue(forKey: id)?.resume(returning: response)
    }

    func fail(_ id: Int, with error: any Error) {
        pending.removeValue(forKey: id)?.resume(throwing: error)
    }

    private func request(_ request: Request) async throws -> Response {
        let id = requests.count
        requests.append(request)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                changes.continuation.yield(())
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    private func cancel(_ id: Int) {
        cancelled.insert(id)
        if respondsToCancellation { pending.removeValue(forKey: id)?.resume(throwing: CancellationError()) }
        changes.continuation.yield(())
    }
}
