import SwiftTUIRuntime

struct DocumentationViewportLink {
    let id: String
    let target: DocumentationLinkTarget
    let rows: Range<Int>
}

@MainActor
struct DocumentationViewportModel {
    let width: Int
    let blocks: [DocumentationTextBlock]
    let links: [DocumentationViewportLink]
    let blockHeights: [Int]
    let height: Int

    init(page: DocumentationPage, width: Int) {
        self.init(
            content: DocumentationViewContent(presentation: DocumentationPresenter().page(page, audience: .human)),
            width: width)
    }

    init(content: DocumentationViewContent, width: Int) {
        self.width = max(1, width)
        blocks = content.blocks
        var links: [DocumentationViewportLink] = []
        var heights: [Int] = []
        var row = 0
        let renderer = DefaultRenderer()
        for block in blocks {
            let frame = renderer.render(block.text(), proposal: .init(width: self.width, height: nil))
            let blockHeight = frame.rasterSurface.lines.count
            // The public focus sequence follows authored inline links. Geometry comes from
            // SwiftTUI, not label matching or a second terminal text-layout implementation.
            for (link, region) in zip(block.links, frame.semanticSnapshot.focusRegions) {
                let start = row + region.rect.origin.y
                links.append(
                    .init(
                        id: link.id, target: link.target,
                        rows: start..<(start + region.rect.size.height)))
            }
            heights.append(blockHeight)
            row += blockHeight + 1
        }
        self.links = links
        blockHeights = heights
        height = max(0, row - 1)
    }

    func restoring(_ viewport: BrowserViewport, height: Int) -> BrowserViewport {
        BrowserViewport(
            topRow: min(max(0, viewport.topRow), max(0, self.height - max(1, height))),
            selectedLinkID: links.contains { $0.id == viewport.selectedLinkID } ? viewport.selectedLinkID : nil)
    }

    func selectLink(step: Int, viewport: BrowserViewport, height: Int) -> BrowserViewport {
        guard !links.isEmpty else { return restoring(viewport, height: height) }
        let current = links.firstIndex { $0.id == viewport.selectedLinkID }
        let index = current.map { min(max(0, $0 + step), links.count - 1) } ?? (step < 0 ? links.count - 1 : 0)
        let link = links[index]
        var selected = restoring(viewport, height: height)
        selected.selectedLinkID = link.id
        if link.rows.lowerBound < selected.topRow || link.rows.count >= height {
            selected.topRow = link.rows.lowerBound
        } else if link.rows.upperBound > selected.topRow + height {
            selected.topRow = link.rows.upperBound - height
        }
        return restoring(selected, height: height)
    }
}

struct DocumentationView: View {
    let model: DocumentationViewportModel
    let viewport: BrowserViewport
    let send: @MainActor @Sendable (BrowserAction) -> Void

    var body: some View {
        ScrollView(
            .vertical,
            position: Binding(
                get: { ScrollCellOffset(x: 0, y: viewport.topRow) },
                set: { offset in
                    var updated = viewport
                    updated.topRow = offset.y
                    if updated != viewport { send(.updateViewport(updated)) }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(model.blocks.enumerated()), id: \.element.id) { index, block in
                    block.text(selectedLinkID: viewport.selectedLinkID)
                        .frame(width: model.width, height: model.blockHeights[index], alignment: .topLeading)
                        .id(block.id)
                }
            }
        }
        .scrollIndicators(.never)
    }
}
