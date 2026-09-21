import SwiftTUIRuntime

struct BrowserView: View {
    let state: BrowserState
    let logs: [SessionLogEntry]
    let send: @MainActor @Sendable (BrowserAction) -> Void
    @Environment(\.requestTermination) private var requestTermination
    @FocusState private var focusedPane: BrowserFocus?
    @State private var logViewport = LogViewport()

    var body: some View {
        GeometryReader { geometry in
            let focusBinding = $focusedPane
            let width = max(1, geometry.size.width)
            let showsNavigator = state.navigatorVisible && width >= 69
            let documentWidth = max(1, width - (showsNavigator ? 29 : 0))
            let logHeight = state.logsVisible ? min(8, max(2, geometry.size.height / 3)) : 0
            let statusHeight = status == nil ? 0 : 1
            let mainHeight = max(2, geometry.size.height - 2 - logHeight - statusHeight)
            let model = DocumentationViewportModel(
                content: DocumentationViewContent(state: state), width: documentWidth)
            let focus = state.focus == .navigator && !showsNavigator ? BrowserFocus.document : state.focus
            let mapper = TerminalKeyMapper(
                document: model, viewportHeight: max(1, mainHeight - 1),
                showsNavigator: showsNavigator)
            VStack(alignment: .leading, spacing: 0) {
                Text(header).bold().lineLimit(1).frame(height: 1, alignment: .leading)
                HStack(alignment: .top, spacing: 1) {
                    if showsNavigator {
                        NavigatorView(state: state, send: send)
                            .focused($focusedPane, equals: .navigator)
                            .frame(width: 28, height: mainHeight, alignment: .topLeading)
                    }
                    mainPane(model: model)
                        .frame(width: documentWidth, height: mainHeight, alignment: .topLeading)
                }
                if let status { Text(terminalSafeText(status)).lineLimit(1).frame(height: 1, alignment: .leading) }
                if state.logsVisible {
                    LogPanel(entries: logs, viewport: $logViewport)
                        .focused($focusedPane, equals: .logs)
                        .frame(height: logHeight)
                }
                Text(footer(focus)).lineLimit(1).frame(height: 1, alignment: .leading)
            }
            .defaultFocus($focusedPane, .document)
            .onChange(of: [state.focus, focus], initial: true) {
                focusBinding.wrappedValue = focus
                if focus != state.focus { send(.setFocus(focus)) }
            }
            .onChange(of: focusBinding.wrappedValue) {
                if let focused = focusBinding.wrappedValue, focused != state.focus { send(.setFocus(focused)) }
            }
            .onKeyPress { key in
                guard let action = mapper.action(for: key, focus: focus, state: state) else { return .ignored }
                send(action)
                if action == .quit { requestTermination() }
                return .handled
            }
            .environment(
                \.openLinkAction,
                OpenLinkAction { destination in
                    guard let link = model.links.first(where: { linkURL($0.target) == destination.rawValue }),
                        let action = TerminalKeyMapper.activation(link.target)
                    else { return false }
                    send(action)
                    return true
                })
        }
    }

    @ViewBuilder private func mainPane(model: DocumentationViewportModel) -> some View {
        if let search = state.search, search.isOpen {
            SearchPanel(state: search, focus: $focusedPane, send: send)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("Documentation").bold().lineLimit(1)
                DocumentationView(model: model, viewport: state.viewport, send: send)
                    .focused($focusedPane, equals: .document)
            }
        }
    }

    private var header: String {
        terminalSafeText(
            ["apple-docs", state.technology, state.currentPage?.title].compactMap { $0 }.joined(separator: " · "))
    }

    private var status: String? {
        if let error = state.pageError { return error + " · r: retry" }
        if let error = state.externalError { return "Browser: " + error }
        if state.pendingPageRequestID != nil { return "Loading documentation… · Escape cancels" }
        return nil
    }

    private func footer(_ focus: BrowserFocus) -> String {
        switch focus {
        case .searchInput: return "Enter submit · Tab results · Escape close"
        case .searchResults: return "↑↓ select · Enter open · Tab query · Escape close"
        case .navigator: return "↑↓ select · ←→ expand · Enter open · Tab document · Ctrl+B hide"
        case .document: return "↑↓ scroll · [] links · Enter open · / search · ` logs · q quit"
        case .logs: return "↑↓ scroll logs · ` or Escape close · q quit"
        }
    }

    private func linkURL(_ target: DocumentationLinkTarget) -> String? {
        switch target {
        case .documentation(let destination): return destination.url.absoluteString
        case .external(let url): return url.absoluteString
        case .unavailable: return nil
        }
    }
}
