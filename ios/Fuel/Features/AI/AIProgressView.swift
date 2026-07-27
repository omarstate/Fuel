import SwiftUI

// A friendly in-flight state for the slow AI calls (lookup / estimate can take
// 10–30s). A spinner plus a hint line that rotates every ~2.2s so the wait feels
// alive rather than stuck. Content, never glass.
struct AIProgressView: View {
  let hints: [LocalizedStringKey]
  var title: LocalizedStringKey?

  @State private var index = 0

  var body: some View {
    VStack(spacing: 14) {
      ProgressView()
        .controlSize(.large)
        .tint(Color.fuelVoltInk)

      if let title {
        Text(title)
          .font(.fuelHeading(.headline))
          .foregroundStyle(Color.fuelInk)
          .multilineTextAlignment(.center)
      }

      if !hints.isEmpty {
        Text(hints[index % hints.count])
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
          .multilineTextAlignment(.center)
          .id(index)
          .transition(.opacity.combined(with: .move(edge: .bottom)))
          .frame(maxWidth: .infinity)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 28)
    .task {
      guard hints.count > 1 else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2.2))
        if Task.isCancelled { break }
        withAnimation(.easeInOut(duration: 0.35)) { index += 1 }
      }
    }
  }
}

#Preview {
  AIProgressView(
    hints: ["Searching the web…", "Reading nutrition data…", "Checking the catalog…"],
    title: "Looking that up…"
  )
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
