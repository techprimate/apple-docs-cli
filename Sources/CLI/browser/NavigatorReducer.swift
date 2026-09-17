enum NavigatorReducer {
    static func reduce(state: inout NavigatorState, action: BrowserAction) -> [BrowserEffect] {
        switch action {
        case .expand(let id): return expand(nodeID: id, state: &state)
        case .collapse(let id): collapse(nodeID: id, state: &state)
        case .childrenLoaded(let id, let requestID, let page):
            childrenLoaded(nodeID: id, requestID: requestID, page: page, state: &state)
        case .childrenFailed(let id, let requestID, let message):
            childrenFailed(nodeID: id, requestID: requestID, message: message, state: &state)
        default: break
        }
        return []
    }

    static func installRoot(_ page: DocumentationPage, state: inout NavigatorState) {
        let id = NavigatorNodeID(components: [page.destination.technology, "root", page.destination.path])
        for root in state.roots where root != id { removeSubtree(root, state: &state) }
        state.roots = [id]
        state.insert(
            NavigatorNode(
                id: id, title: page.title, target: .documentation(page.destination), parentID: nil, isExpanded: true
            ))
        populate(page, under: id, state: &state)
        if let current = state.currentPage { showCurrentPage(current, state: &state) }
        if state.selectedID == nil { state.selectedID = id }
    }

    static func expand(nodeID: NavigatorNodeID, state: inout NavigatorState) -> [BrowserEffect] {
        guard var node = state.nodes[nodeID], !node.isCycle else { return [] }
        if node.loadState == .loaded && node.children.isEmpty { return [] }
        node.isExpanded = true
        state.nodes[nodeID] = node
        switch node.loadState {
        case .loaded, .loading: return []
        case .unloaded, .failed:
            guard let destination = node.destination else { return [] }
            state.nextRequestID += 1
            state.nodes[nodeID]?.loadState = .loading(state.nextRequestID)
            return [.loadChildren(nodeID: nodeID, requestID: state.nextRequestID, destination: destination)]
        }
    }

    static func collapse(nodeID: NavigatorNodeID, state: inout NavigatorState) {
        state.nodes[nodeID]?.isExpanded = false
    }

    static func childrenLoaded(
        nodeID: NavigatorNodeID, requestID: UInt64, page: DocumentationPage, state: inout NavigatorState
    ) {
        guard state.nodes[nodeID]?.loadState == .loading(requestID) else { return }
        populate(page, under: nodeID, state: &state)
        if let current = state.currentPage { showCurrentPage(current, state: &state) }
    }

    static func childrenFailed(
        nodeID: NavigatorNodeID, requestID: UInt64, message: String, state: inout NavigatorState
    ) {
        guard state.nodes[nodeID]?.loadState == .loading(requestID) else { return }
        state.nodes[nodeID]?.loadState = .failed(message)
    }

    static func showCurrentPage(_ page: DocumentationPage, state: inout NavigatorState) {
        state.currentPage = page
        let oldShortcut = state.currentPageShortcut
        let selectedDestination = state.selectedID.flatMap { state.nodes[$0]?.destination }
        let selectedShortcut =
            oldShortcut.map { shortcut in
                state.selectedID?.components.starts(with: shortcut.components) == true
            } ?? false
        if let occurrence = state.occurrence(of: page.destination) {
            if let oldShortcut { removeSubtree(oldShortcut, state: &state) }
            state.currentPageShortcut = nil
            populate(page, under: occurrence, state: &state)
            if selectedShortcut || state.selectedID == nil {
                state.selectedID = selectedDestination.flatMap { state.occurrence(of: $0) } ?? occurrence
                state.reveal(state.selectedID)
            }
        } else {
            let id = NavigatorNodeID(components: [page.destination.technology, "current", page.destination.path])
            if let oldShortcut, oldShortcut != id { removeSubtree(oldShortcut, state: &state) }
            state.currentPageShortcut = id
            state.insert(
                NavigatorNode(
                    id: id, title: "Current page: " + page.title, target: .documentation(page.destination),
                    parentID: nil
                ))
            populate(page, under: id, state: &state)
            if selectedShortcut || state.selectedID == nil { state.selectedID = id }
        }
    }

    private static func populate(
        _ page: DocumentationPage, under parentID: NavigatorNodeID, state: inout NavigatorState
    ) {
        guard state.nodes[parentID]?.isCycle == false else { return }
        let groups = page.topics.map { group in
            let groupID = NavigatorNodeID(components: parentID.components + ["group:" + group.id])
            state.insert(
                NavigatorNode(id: groupID, title: group.title, target: nil, parentID: parentID, loadState: .loaded))
            let children = group.references.enumerated().map { index, reference in
                let id = NavigatorNodeID(components: groupID.components + [reference.id, "occurrence:\(index)"])
                let cycle = isAncestor(reference.target, of: parentID, state: state)
                let destination: DocumentationDestination?
                if case .documentation(let value) = reference.target { destination = value } else { destination = nil }
                state.insert(
                    NavigatorNode(
                        id: id, title: reference.title, target: reference.target, parentID: groupID,
                        loadState: cycle || destination == nil ? .loaded : .unloaded, isCycle: cycle
                    ))
                return id
            }
            state.nodes[groupID]?.children = children
            return groupID
        }
        state.nodes[parentID]?.children = groups
        state.nodes[parentID]?.loadState = .loaded
        if groups.isEmpty { state.nodes[parentID]?.isExpanded = false }
    }

    private static func isAncestor(
        _ target: DocumentationLinkTarget, of nodeID: NavigatorNodeID, state: NavigatorState
    ) -> Bool {
        guard case .documentation(let destination) = target else { return false }
        var current: NavigatorNodeID? = nodeID
        while let id = current, let node = state.nodes[id] {
            if node.destination?.path == destination.path && node.destination?.technology == destination.technology {
                return true
            }
            current = node.parentID
        }
        return false
    }

    private static func removeSubtree(_ nodeID: NavigatorNodeID, state: inout NavigatorState) {
        for child in state.nodes[nodeID]?.children ?? [] { removeSubtree(child, state: &state) }
        state.nodes.removeValue(forKey: nodeID)
        state.restoredExpandedIDs.remove(nodeID)
    }
}
