import Foundation
import Twill

struct BrowserView: View {
    #if DEBUG
        typealias Client = any TechnologyCatalogRepository
    #else
        typealias Client = TechnologyCatalogRepository
    #endif

    private enum Focus: Hashable {
        case search
        case technologies
    }

    private let client: Client

    @State private var technologies: [Technology] = []
    @State private var errorMessage: String?
    @State private var query = ""
    @FocusState private var focus: Focus? = .technologies

    private var filteredTechnologies: [Technology] {
        query.isEmpty ? technologies : technologies.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    init(client: Client) {
        self.client = client
    }

    var body: some View {
        VStack {
            Text("Apple Docs CLI")
            HStack {
                Text("Search:")
                TextField("Search technologies", text: $query)
                    .focused($focus, equals: .search)
                    .onSubmit { focus = .technologies }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    if !query.isEmpty && filteredTechnologies.isEmpty {
                        Text("No matching technologies")
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                            ForEach(filteredTechnologies) { technology in
                                Button(technology.name) {}
                            }
                        }
                    }
                }
                .focused($focus, equals: .technologies)
                .border(.single, color: Color.white)
                .onKeyPress { key in
                    switch key {
                    case .g:
                        guard let first = filteredTechnologies.first else { return .ignored }
                        proxy.scrollTo(first.id, anchor: .top)
                    case .G:
                        guard let last = filteredTechnologies.last else { return .ignored }
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
            KeyBindingsFooter(bindings: [
                .init(key: "Arrows", action: "Move"),
                .init(key: "g/G", action: "Top/Bottom"),
                .init(key: "/", action: "Search"),
            ])
        }
        .onKeyPress { key in
            switch key {
            case .slash: focus = .search
            case .escape where focus == .search: focus = .technologies
            default: return .ignored
            }
            return .handled
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
