import SwiftTUIRuntime

struct SearchPanel: View {
    let state: SearchState
    let focus: FocusState<BrowserFocus?>.Binding
    let query: Binding<String>
    let selection: Binding<Int?>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Search · " + terminalSafeText(state.technology)).bold()
            TextField("Symbol name or path", text: query)
                .focused(focus, equals: .searchInput)
            Text("Enter submits · Tab selects results").lineLimit(1)
            if state.pendingRequestID != nil { Text("Searching collections…") }
            if let error = state.error { Text(terminalSafeText(error)) }
            if !state.unavailableCollectionPaths.isEmpty {
                Text("Incomplete: \(state.unavailableCollectionPaths.count) collections unavailable").lineLimit(1)
            }
            if state.hasSearched && state.results.isEmpty { Text("No matching symbols") }
            ScrollViewReader { proxy in
                List(
                    Array(state.results.enumerated()), id: \.offset,
                    selection: selection
                ) { _, result in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(terminalSafeText(result.name + " · " + result.kind)).lineLimit(1)
                        Text(terminalSafeText(result.path)).lineLimit(1)
                    }
                }
                .focusable()
                .focused(focus, equals: .searchResults)
                .onChange(of: state.selectedResultIndex) {
                    if let index = state.selectedResultIndex { proxy.scrollTo(index) }
                }
            }
        }
    }
}
