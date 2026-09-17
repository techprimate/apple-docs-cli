import SwiftTUIRuntime

@MainActor
struct TerminalKeyMapper {
    var document: DocumentationViewportModel?
    var viewportHeight = 1
    var showsNavigator = true

    func action(for key: KeyPress, focus: BrowserFocus, state: BrowserState) -> BrowserAction? {
        if !key.modifiers.isEmpty && key != .init(.tab, modifiers: .shift) {
            return modifiedShortcut(key, focus: focus)
        }
        if key.key == .escape || key.key == .tab { return focusShortcut(key.key, focus: focus, state: state) }
        if focus == .searchInput { return key.key == .return ? .submitSearch : nil }
        if let action = printableShortcut(key.key, focus: focus, state: state) { return action }
        switch focus {
        case .navigator: return navigatorAction(key.key, state: state)
        case .document: return documentAction(key.key, state: state)
        case .searchResults: return searchAction(key.key, state: state)
        case .searchInput, .logs: return nil
        }
    }

    private func modifiedShortcut(_ key: KeyPress, focus: BrowserFocus) -> BrowserAction? {
        if key == .init(.character("c"), modifiers: .ctrl) { return .quit }
        if key == .init(.arrowLeft, modifiers: .alt) { return .back }
        if key == .init(.arrowRight, modifiers: .alt) { return .forward }
        if key == .init(.character("b"), modifiers: .ctrl), focus == .document || focus == .navigator {
            return .toggleNavigator
        }
        return nil
    }

    private func focusShortcut(_ key: KeyEvent, focus: BrowserFocus, state: BrowserState) -> BrowserAction {
        if key == .escape {
            if focus == .document && !showsNavigator && state.search?.isOpen != true && state.pendingNavigation == nil {
                return .setFocus(.document)
            }
            return .escape
        }
        return focus == .document && !showsNavigator && state.search?.isOpen != true ? .setFocus(.document) : .tab
    }

    private func printableShortcut(_ key: KeyEvent, focus: BrowserFocus, state: BrowserState) -> BrowserAction? {
        switch key {
        case .character("q"): return .quit
        case .character("`"): return .toggleLogs
        case .character("/"): return state.technology == nil ? nil : .showSearch
        case .character("o"): return state.currentPage.map { .openExternal($0.url) }
        case .character("r"):
            if focus == .navigator, let technology = state.technology, state.catalog.rootErrors[technology] != nil {
                return .retryRoot(technology: technology)
            }
            return .retry
        default: return nil
        }
    }

    static func activation(_ target: DocumentationLinkTarget) -> BrowserAction? {
        switch target {
        case .documentation(let destination): return .open(destination)
        case .external(let url): return .openExternal(url)
        case .unavailable: return nil
        }
    }

    private func documentAction(_ key: KeyEvent, state: BrowserState) -> BrowserAction? {
        guard let document else { return nil }
        var viewport = state.viewport
        switch key {
        case .character("]"), .character("["):
            viewport = document.selectLink(
                step: key == .character("]") ? 1 : -1,
                viewport: viewport, height: viewportHeight)
        case .return:
            return document.links.first { $0.id == viewport.selectedLinkID }.flatMap { Self.activation($0.target) }
        case .arrowUp: viewport.topRow -= 1
        case .arrowDown: viewport.topRow += 1
        case .pageUp: viewport.topRow -= max(1, viewportHeight - 1)
        case .pageDown: viewport.topRow += max(1, viewportHeight - 1)
        default: return nil
        }
        return .updateViewport(document.restoring(viewport, height: viewportHeight))
    }

    private func navigatorAction(_ key: KeyEvent, state: BrowserState) -> BrowserAction? {
        let tree = state.navigatorTree
        let rows = tree.visibleRows()
        if key == .arrowUp || key == .arrowDown {
            guard !rows.isEmpty else { return nil }
            let current = rows.firstIndex { $0.id == tree.selectedID }
            let index = current.map { min(max(0, $0 + (key == .arrowDown ? 1 : -1)), rows.count - 1) } ?? 0
            var snapshot = tree.snapshot
            snapshot.selectedID = rows[index].id
            snapshot.topRow = min(snapshot.topRow, index)
            if index >= snapshot.topRow + viewportHeight { snapshot.topRow = index - viewportHeight + 1 }
            return .updateNavigator(snapshot)
        }
        guard let id = tree.selectedID, let node = tree.nodes[id] else { return nil }
        switch key {
        case .arrowRight: return .expand(id)
        case .arrowLeft: return .collapse(id)
        case .return: return node.target.flatMap(Self.activation) ?? (node.target == nil ? .expand(id) : nil)
        default: return nil
        }
    }

    private func searchAction(_ key: KeyEvent, state: BrowserState) -> BrowserAction? {
        guard let search = state.search, !search.results.isEmpty else { return nil }
        let current = search.selectedResultIndex ?? 0
        switch key {
        case .arrowDown: return .selectSearchResult(min(current + 1, search.results.count - 1))
        case .arrowUp: return .selectSearchResult(max(0, current - 1))
        case .return: return .activateSearchResult(current)
        default: return nil
        }
    }
}
