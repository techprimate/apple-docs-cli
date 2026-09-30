import Twill

struct BrowserView: View {
    private let client: any TechnologyCatalogClient

    @State private var technologies: [Technology] = []

    init(client: any TechnologyCatalogClient) {
        self.client = client
    }

    var body: some View {
        VStack {
            Text("Apple Docs CLI")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                ForEach(technologies, id: \.name) { technology in
                    Text(technology.name)
                }
            }
            .border(.single, color: Color.white)
        }
        .task {
            technologies = await client.fetchTechnologies()
        }
    }
}
