import SwiftUI

// A minimal wrapping row layout — the SwiftUI equivalent of the web's
// `flex flex-wrap gap-1.5`. Used for the set pills on an exercise card and the
// catalog suggestion chips, both of which are variable-width and must wrap
// rather than scroll.
//
// The codebase had no flow layout when this was written; LazyVGrid's adaptive
// columns were rejected because they force every cell to a uniform width, which
// makes short pills ("#1 40 × 8") sit in the same box as long chip names.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8
  var lineSpacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? .infinity
    let rows = arrange(subviews: subviews, in: width)
    let height = rows.reduce(0.0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
    return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let rows = arrange(subviews: subviews, in: bounds.width)
    var y = bounds.minY
    for row in rows {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(
          at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
          proposal: ProposedViewSize(size)
        )
        x += size.width + spacing
      }
      y += row.height + lineSpacing
    }
  }

  // Greedy line-breaking: keep adding subviews until the next one would overflow.
  private func arrange(subviews: Subviews, in width: CGFloat) -> [Row] {
    var rows: [Row] = []
    var current = Row()
    var x: CGFloat = 0

    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      let needed = current.indices.isEmpty ? size.width : x + spacing + size.width
      if !current.indices.isEmpty, needed > width {
        rows.append(current)
        current = Row()
        x = 0
      }
      current.indices.append(index)
      current.height = max(current.height, size.height)
      x = current.indices.count == 1 ? size.width : x + spacing + size.width
      current.width = x
    }
    if !current.indices.isEmpty { rows.append(current) }
    return rows
  }

  private struct Row {
    var indices: [Subviews.Index] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }
}
