enum BrowserReducer {
    static func reduce(state: inout BrowserState, action: BrowserAction) -> [BrowserEffect] {
        switch action {
        case .open, .pageLoaded, .pageFailed, .retry, .back, .forward:
            return navigation(state: &state, action: action)
        case .toggleNavigator, .toggleLogs, .tab, .escape:
            return focus(state: &state, action: action)
        case .quit:
            return cancel(state: &state) + [.quit]
        }
    }

    private static func navigation(state: inout BrowserState, action: BrowserAction) -> [BrowserEffect] {
        switch action {
        case .open(let destination): return begin(destination, history: nil, state: &state)
        case .pageLoaded(let requestID, let loaded):
            guard let request = state.pendingNavigation, request.id == requestID else { return [] }
            complete(loaded.page, request: request, state: &state)
        case .pageFailed(let requestID, let message):
            guard state.pendingPageRequestID == requestID else { return [] }
            state.failedNavigation = state.pendingNavigation
            state.pendingNavigation = nil
            state.pageError = message
        case .retry:
            guard let failed = state.failedNavigation else { return [] }
            return begin(failed.destination, history: failed.history, state: &state)
        case .back, .forward: return travel(back: action == .back, state: &state)
        default: break
        }
        return []
    }

    private static func focus(state: inout BrowserState, action: BrowserAction) -> [BrowserEffect] {
        switch action {
        case .toggleNavigator: toggleNavigator(state: &state)
        case .toggleLogs: toggleLogs(state: &state)
        case .tab:
            if state.focus == .navigator {
                state.focus = .document
            } else if state.focus == .document && state.navigatorVisible {
                state.focus = .navigator
            }
        case .escape: return escape(state: &state)
        default: break
        }
        return []
    }

    private static func toggleNavigator(state: inout BrowserState) {
        state.navigatorVisible.toggle()
        if !state.navigatorVisible {
            if state.focus == .navigator { state.focus = .document }
            if state.previousLogFocus == .navigator { state.previousLogFocus = .document }
        }
    }

    private static func begin(
        _ destination: DocumentationDestination, history: BrowserHistory?, state: inout BrowserState
    ) -> [BrowserEffect] {
        if let snapshot = state.snapshot { state.history.updateCurrent(snapshot) }
        let effects = cancel(state: &state)
        state.nextRequestID += 1
        state.pendingNavigation = BrowserPageRequest(
            id: state.nextRequestID, destination: destination, history: history)
        state.failedNavigation = nil
        state.pageError = nil
        return effects + [.loadPage(requestID: state.nextRequestID, destination: destination)]
    }

    private static func complete(_ page: DocumentationPage, request: BrowserPageRequest, state: inout BrowserState) {
        let previousTechnology = state.technology
        state.pendingNavigation = nil
        state.failedNavigation = nil
        state.pageError = nil
        state.currentPage = page
        state.currentLocation = .page(request.destination)
        if let history = request.history, let entry = history.current {
            state.history = history
            restore(entry, state: &state)
        } else {
            state.viewport = BrowserViewport()
            focusMainPane(.document, state: &state)
            if previousTechnology != page.destination.technology { state.navigator = NavigatorSnapshot() }
            if let snapshot = state.snapshot { state.history.visit(snapshot) }
        }
    }

    private static func travel(back: Bool, state: inout BrowserState) -> [BrowserEffect] {
        if let snapshot = state.snapshot { state.history.updateCurrent(snapshot) }
        var history = state.history
        guard let entry = back ? history.back() : history.forward() else { return [] }
        if case .page(let destination) = entry.location {
            return begin(destination, history: history, state: &state)
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
            state.focus = state.previousLogFocus
        } else {
            state.previousLogFocus = state.focus
            state.logsVisible = true
            state.focus = .logs
        }
    }

    private static func escape(state: inout BrowserState) -> [BrowserEffect] {
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
