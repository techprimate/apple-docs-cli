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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                ForEach(technologies) { technology in
                    Text(technology.name)
                }
            }
            .border(.single, color: Color.white)
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
