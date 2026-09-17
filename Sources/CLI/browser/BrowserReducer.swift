enum BrowserReducer {
    static func reduce(state: inout BrowserState, action: BrowserAction) -> [BrowserEffect] {
        switch action {
        case .start, .ensureRoot, .retryRoot, .rootLoaded, .rootFailed, .typesLoaded, .typesFailed, .technologiesLoaded,
            .technologiesFailed:
            return BrowserEntryReducer.reduce(state: &state, action: action)
        case .open, .openNamed, .pageLoaded, .pageFailed, .retry, .back, .forward:
            return navigation(state: &state, action: action)
        case .expand, .collapse, .childrenLoaded, .childrenFailed:
            return tree(state: &state, action: action)
        case .showSearch, .editQuery, .submitSearch, .searchLoaded, .searchFailed, .selectSearchResult,
            .activateSearchResult,
            .dismissSearch:
            return SearchReducer.reduceBrowser(state: &state, action: action)
        case .openExternal, .externalOpened, .externalFailed:
            return external(state: &state, action: action)
        case .setFocus, .toggleNavigator, .toggleLogs, .tab, .escape:
            return focus(state: &state, action: action)
        case .updateNavigator(let snapshot):
            state.navigator = snapshot
            return []
        case .updateViewport(let viewport):
            state.viewport = viewport
            return []
        case .operationCancelled(let requestID):
            clearCancelled(requestID, state: &state)
            return []
        case .quit:
            return SearchReducer.dismiss(state: &state) + cancel(state: &state) + [.quit]
        }
    }

    private static func clearCancelled(_ requestID: UInt64, state: inout BrowserState) {
        BrowserEntryReducer.clearCancelled(requestID, state: &state)
        if state.pendingPageRequestID == requestID { state.pendingNavigation = nil }
        if state.pendingExternalRequestID == requestID { state.pendingExternalRequestID = nil }
        for technology in state.technologySearches.keys
        where state.technologySearches[technology]?.pendingRequestID == requestID {
            state.technologySearches[technology]?.pendingRequestID = nil
        }
        for technology in state.technologyNavigators.keys {
            guard var navigator = state.technologyNavigators[technology] else { continue }
            for id in navigator.nodes.keys where navigator.nodes[id]?.loadState == .loading(requestID) {
                navigator.nodes[id]?.loadState = .unloaded
            }
            state.technologyNavigators[technology] = navigator
        }
    }

    private static func external(state: inout BrowserState, action: BrowserAction) -> [BrowserEffect] {
        switch action {
        case .openExternal(let url):
            state.nextRequestID += 1
            state.pendingExternalRequestID = state.nextRequestID
            state.externalError = nil
            return [.openExternal(requestID: state.nextRequestID, url: url)]
        case .externalOpened(let requestID):
            if state.pendingExternalRequestID == requestID { state.pendingExternalRequestID = nil }
        case .externalFailed(let requestID, let message):
            guard state.pendingExternalRequestID == requestID else { return [] }
            state.pendingExternalRequestID = nil
            state.externalError = message
        default: break
        }
        return []
    }

    private static func tree(state: inout BrowserState, action: BrowserAction) -> [BrowserEffect] {
        guard let technology = action.navigatorNodeID?.components.first,
            var navigator = state.technologyNavigators[technology]
        else { return [] }
        navigator.nextRequestID = state.nextRequestID
        let effects = NavigatorReducer.reduce(state: &navigator, action: action)
        state.nextRequestID = navigator.nextRequestID
        state.technologyNavigators[technology] = navigator
        return effects
    }

    private static func navigation(state: inout BrowserState, action: BrowserAction) -> [BrowserEffect] {
        switch action {
        case .open(let destination): return begin(.exact(destination), history: nil, state: &state)
        case .openNamed(let name, let technology):
            return begin(.named(name: name, technology: technology), history: nil, state: &state)
        case .pageLoaded(let requestID, let loaded):
            return pageLoaded(loaded, requestID: requestID, state: &state)
        case .pageFailed(let requestID, let message):
            guard state.pendingPageRequestID == requestID else { return [] }
            state.failedNavigation = state.pendingNavigation
            state.pendingNavigation = nil
            state.pageError = message
        case .retry:
            guard let failed = state.failedNavigation else { return BrowserEntryReducer.retryCatalog(state: &state) }
            return begin(failed.target, history: failed.history, state: &state)
        case .back, .forward:
            return SearchReducer.dismiss(state: &state) + travel(back: action == .back, state: &state)
        default: break
        }
        return []
    }

    private static func pageLoaded(
        _ loaded: LoadedDocumentationPage, requestID: UInt64, state: inout BrowserState
    ) -> [BrowserEffect] {
        guard let request = state.pendingNavigation, request.id == requestID else { return [] }
        if case .named(_, let technology) = request.target {
            BrowserEntryReducer.register(technology, canonical: loaded.page.destination.technology, state: &state)
        }
        let effects = state.technology == loaded.page.destination.technology ? [] : SearchReducer.dismiss(state: &state)
        complete(loaded.page, request: request, state: &state)
        return effects
    }

    private static func focus(state: inout BrowserState, action: BrowserAction) -> [BrowserEffect] {
        switch action {
        case .setFocus(let focus): state.focus = focus
        case .toggleNavigator: toggleNavigator(state: &state)
        case .toggleLogs: toggleLogs(state: &state)
        case .tab: tab(state: &state)
        case .escape: return escape(state: &state)
        default: break
        }
        return []
    }

    private static func tab(state: inout BrowserState) {
        if state.search?.isOpen == true {
            if state.focus == .searchInput {
                state.focus = .searchResults
            } else if state.focus == .searchResults {
                state.focus = .searchInput
            }
        } else if state.focus == .navigator {
            state.focus = .document
        } else if state.focus == .document && state.navigatorVisible {
            state.focus = .navigator
        }
    }

    private static func toggleNavigator(state: inout BrowserState) {
        state.navigatorVisible.toggle()
        if !state.navigatorVisible {
            if state.focus == .navigator { state.focus = .document }
            if state.previousLogFocus == .navigator { state.previousLogFocus = .document }
        }
    }

    private static func begin(
        _ target: BrowserPageTarget, history: BrowserHistory?, state: inout BrowserState
    ) -> [BrowserEffect] {
        let searchEffects = SearchReducer.dismiss(state: &state)
        if let snapshot = state.snapshot { state.history.updateCurrent(snapshot) }
        let effects = searchEffects + cancel(state: &state)
        state.nextRequestID += 1
        state.pendingNavigation = BrowserPageRequest(
            id: state.nextRequestID, target: target, history: history)
        state.failedNavigation = nil
        state.pageError = nil
        return effects + [target.effect(requestID: state.nextRequestID)]
    }

    private static func complete(_ page: DocumentationPage, request: BrowserPageRequest, state: inout BrowserState) {
        state.pendingNavigation = nil
        state.failedNavigation = nil
        state.pageError = nil
        state.currentPage = page
        state.currentLocation = .page(request.target.destination ?? page.destination)
        NavigatorReducer.showCurrentPage(page, state: &state.navigatorTree)
        if let history = request.history, let entry = history.current {
            state.history = history
            restore(entry, state: &state)
        } else {
            state.viewport = BrowserViewport()
            focusMainPane(.document, state: &state)
            if let snapshot = state.snapshot { state.history.visit(snapshot) }
        }
    }

    private static func travel(back: Bool, state: inout BrowserState) -> [BrowserEffect] {
        if let snapshot = state.snapshot { state.history.updateCurrent(snapshot) }
        var history = state.history
        guard let entry = back ? history.back() : history.forward() else { return [] }
        if case .page(let destination) = entry.location {
            return begin(.exact(destination), history: history, state: &state)
        }
        let effects = cancel(state: &state)
        state.pageError = nil
        state.failedNavigation = nil
        state.currentPage = nil
        state.currentLocation = entry.location
        state.history = history
        restore(entry, state: &state)
        return effects
    }

    private static func restore(_ entry: BrowserHistoryEntry, state: inout BrowserState) {
        state.viewport = entry.viewport
        state.navigator = entry.navigator
        let focus: BrowserFocus = entry.focus == .navigator && !state.navigatorVisible ? .document : entry.focus
        focusMainPane(focus, state: &state)
    }

    private static func focusMainPane(_ focus: BrowserFocus, state: inout BrowserState) {
        if SearchReducer.focusUnderlyingPane(focus, state: &state) { return }
        if state.logsVisible && state.focus == .logs { state.previousLogFocus = focus } else { state.focus = focus }
    }

    private static func cancel(state: inout BrowserState) -> [BrowserEffect] {
        guard let request = state.pendingNavigation else { return [] }
        state.pendingNavigation = nil
        return [.cancelPage(requestID: request.id)]
    }

    private static func toggleLogs(state: inout BrowserState) {
        if state.logsVisible {
            state.logsVisible = false
            if state.focus == .logs { state.focus = state.previousLogFocus }
        } else {
            state.previousLogFocus = state.focus
            state.logsVisible = true
            state.focus = .logs
        }
    }

    private static func escape(state: inout BrowserState) -> [BrowserEffect] {
        if state.search?.isOpen == true { return SearchReducer.dismiss(state: &state) }
        if state.logsVisible && state.focus == .logs {
            toggleLogs(state: &state)
        } else if state.pendingNavigation != nil {
            return cancel(state: &state)
        } else if state.focus == .document && state.navigatorVisible {
            state.focus = .navigator
        }
        return []
    }
}
