enum SupportRequest: Sendable {
    case articles(category: String?)
    case helpCatalog
    case contents(name: String)
    case glossary(query: String?)
    case glossaryEntry(term: String)
    case terms(category: String?)
    case termsEntry(name: String)
    case article(path: String)

    var commandName: String {
        switch self {
        case .articles: return "support.articles.list"
        case .helpCatalog: return "support.guides.list"
        case .contents: return "support.guides.contents"
        case .glossary: return "support.glossary.list"
        case .glossaryEntry: return "support.glossary.view"
        case .terms: return "support.terms.list"
        case .termsEntry: return "support.terms.view"
        case .article: return "support.view"
        }
    }
}

struct SupportCommandRunner: Sendable {
    private let service: AppleSupportService
    private let renderer: SupportRenderer

    init(service: AppleSupportService, renderer: SupportRenderer) {
        self.service = service
        self.renderer = renderer
    }

    func run(_ request: SupportRequest) async throws -> String {
        let payload: SupportPayload
        switch request {
        case .articles(let category): payload = .articles(try await service.fetchArticles(category: category))
        case .helpCatalog: payload = .help(try await service.fetchHelp())
        case .contents(let name): payload = .contents(try await service.fetchGuideContents(named: name))
        case .glossary(let query): payload = .glossary(try await service.fetchGlossary(query: query))
        case .glossaryEntry(let term): payload = .glossaryEntry(try await service.fetchGlossaryEntry(term: term))
        case .terms(let category): payload = .terms(try await service.fetchTerms(category: category))
        case .termsEntry(let name): payload = .termsEntry(try await service.fetchTermsEntry(named: name))
        case .article(let path): payload = .article(try await service.fetchArticle(path: path))
        }
        return try renderer.render(payload)
    }
}
