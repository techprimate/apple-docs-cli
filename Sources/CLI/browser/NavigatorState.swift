struct NavigatorNodeID: Hashable, Sendable {
    let components: [String]
}

struct NavigatorSnapshot: Equatable, Sendable {
    var expandedIDs: Set<NavigatorNodeID> = []
    var selectedID: NavigatorNodeID?
    var topRow = 0
}

enum NavigatorLoadState: Equatable, Sendable {
    case unloaded
    case loading(UInt64)
    case loaded
    case failed(String)
}

struct NavigatorNode: Equatable, Sendable {
    let id: NavigatorNodeID
    let title: String
    let target: DocumentationLinkTarget?
    let parentID: NavigatorNodeID?
    var children: [NavigatorNodeID] = []
    var isExpanded = false
    var loadState: NavigatorLoadState = .unloaded
    var isCycle = false

    var destination: DocumentationDestination? {
        guard case .documentation(let destination) = target else { return nil }
        return destination
    }

    var isLoading: Bool {
        if case .loading = loadState { return true }
        return false
    }

    var error: String? {
        guard case .failed(let message) = loadState else { return nil }
        return message
    }
}

struct NavigatorRow: Equatable, Sendable {
    let node: NavigatorNode
    let depth: Int
    var id: NavigatorNodeID { node.id }
    var title: String { node.title }
}

struct NavigatorState: Equatable, Sendable {
    var nodes: [NavigatorNodeID: NavigatorNode] = [:]
    var roots: [NavigatorNodeID] = []
    var selectedID: NavigatorNodeID?
    var topRow = 0
    var currentPageShortcut: NavigatorNodeID?
    var currentPage: DocumentationPage?
    var nextRequestID: UInt64 = 0
    var restoredExpandedIDs: Set<NavigatorNodeID> = []
    var hasRestoredSnapshot = false

    init() {}

    init(page: DocumentationPage) {
        NavigatorReducer.installRoot(page, state: &self)
    }

    var snapshot: NavigatorSnapshot {
        get {
            let expanded = Set(nodes.values.filter(\.isExpanded).map(\.id))
                .union(restoredExpandedIDs.subtracting(nodes.keys))
            return NavigatorSnapshot(expandedIDs: expanded, selectedID: selectedID, topRow: topRow)
        }
        set {
            restoredExpandedIDs = Set(newValue.expandedIDs.map(relocatedID))
            hasRestoredSnapshot = true
            selectedID = newValue.selectedID.map(relocatedID)
            topRow = newValue.topRow
            for id in nodes.keys { nodes[id]?.isExpanded = restoredExpandedIDs.contains(id) }
            if selectedID != newValue.selectedID { reveal(selectedID) }
        }
    }

    func visibleRows() -> [NavigatorRow] {
        rows(expandedOnly: true, includeShortcut: true)
    }

    func occurrence(of destination: DocumentationDestination) -> NavigatorNodeID? {
        rows(expandedOnly: false, includeShortcut: false).first {
            $0.node.destination?.path == destination.path && $0.node.destination?.technology == destination.technology
        }?.id
    }

    mutating func insert(_ node: NavigatorNode) {
        guard nodes[node.id] == nil else { return }
        var node = node
        if hasRestoredSnapshot { node.isExpanded = restoredExpandedIDs.contains(node.id) && !node.isCycle }
        nodes[node.id] = node
    }

    mutating func reveal(_ nodeID: NavigatorNodeID?) {
        var current = nodeID.flatMap { nodes[$0]?.parentID }
        while let id = current {
            nodes[id]?.isExpanded = true
            current = nodes[id]?.parentID
        }
    }

    private func relocatedID(_ id: NavigatorNodeID) -> NavigatorNodeID {
        guard nodes[id] == nil, id.components.count >= 3, id.components[1] == "current",
            let occurrence = occurrence(
                of: DocumentationDestination(
                    technology: id.components[0], path: id.components[2]))
        else { return id }
        return NavigatorNodeID(components: occurrence.components + id.components.dropFirst(3))
    }

    private func rows(expandedOnly: Bool, includeShortcut: Bool) -> [NavigatorRow] {
        let rootIDs = roots + (includeShortcut ? currentPageShortcut.map { [$0] } ?? [] : [])
        var pending = rootIDs.reversed().map { ($0, 0) }
        var rows: [NavigatorRow] = []
        while let (id, depth) = pending.popLast() {
            guard let node = nodes[id] else { continue }
            rows.append(NavigatorRow(node: node, depth: depth))
            if !expandedOnly || node.isExpanded {
                pending += node.children.reversed().map { ($0, depth + 1) }
            }
        }
        return rows
    }
}
