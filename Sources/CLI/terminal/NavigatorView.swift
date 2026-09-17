import SwiftTUIRuntime

struct NavigatorView: View {
    let state: BrowserState
    let send: @MainActor @Sendable (BrowserAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Navigator").bold()
            if let technology = state.technology, let error = state.catalog.rootErrors[technology] {
                Text(terminalSafeText(error) + " · r: retry").lineLimit(2)
            }
            ScrollView(
                .vertical,
                position: Binding(
                    get: { .init(x: 0, y: state.navigatorTree.topRow) },
                    set: { offset in
                        var snapshot = state.navigator
                        snapshot.topRow = offset.y
                        if snapshot != state.navigator { send(.updateNavigator(snapshot)) }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.navigatorTree.visibleRows(), id: \.id) { row in
                        Text(label(row)).bold(row.id == state.navigatorTree.selectedID)
                            .lineLimit(1)
                            .id(row.id)
                    }
                    if state.navigatorTree.roots.isEmpty {
                        Text(state.technology == nil ? "Choose a technology" : "Loading navigation…")
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }

    private func label(_ row: NavigatorRow) -> String {
        let node = row.node
        let marker: String
        if node.isLoading {
            marker = "…"
        } else if node.error != nil {
            marker = "!"
        } else if node.isExpanded {
            marker = "▾"
        } else if node.isCycle || node.loadState == .loaded && node.children.isEmpty {
            marker = "·"
        } else {
            marker = "▸"
        }
        let selected = node.id == state.navigatorTree.selectedID ? ">" : " "
        return selected + String(repeating: "  ", count: row.depth) + marker + " " + terminalSafeText(row.title)
    }
}
