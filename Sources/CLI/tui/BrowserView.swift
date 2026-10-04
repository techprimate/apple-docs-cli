import Twill

struct BrowserView: View {
    #if DEBUG
        typealias Client = any TechnologyCatalogClient
    #else
        typealias Client = TechnologyCatalogClient
    #endif

    private let client: Client

    @State private var technologies: [Technology] = []
    @State private var errorMessage: String?

    init(client: Client) {
        self.client = client
    }

    var body: some View {
        VStack {
            Text("Apple Docs CLI")
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                        ForEach(technologies) { technology in
                            Text(technology.name)
                        }
                    }
                }
                .border(.single, color: Color.white)
                .onKeyPress { key in
                    switch key {
                    case .g:
                        guard let first = technologies.first else { return .ignored }
                        proxy.scrollTo(first.id, anchor: .top)
                    case .G:
                        guard let last = technologies.last else { return .ignored }
                        proxy.scrollTo(last.id, anchor: .bottom)
                    default:
                        return .ignored
                    }
                    return .handled
                }
            }
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            do {
                technologies = try await client.fetchTechnologies()
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }
}
