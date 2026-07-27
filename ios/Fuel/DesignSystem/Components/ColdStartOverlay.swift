import SwiftUI

// "Waking the server…" overlay for Render free-tier cold starts. Show this
// after ~3s of a still-pending load. Use the `.coldStart(isLoading:)` modifier
// which handles the 3s delay itself.
struct ColdStartOverlay: View {
  var body: some View {
    VStack(spacing: 14) {
      ProgressView()
        .controlSize(.large)
        .tint(Color.fuelVoltInk)
      Text("Waking the server…")
        .font(.fuelHeading(.headline))
        .foregroundStyle(Color.fuelInk)
      Text("Free-tier servers nap after a while. This can take up to a minute.")
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.fuelBackground)
    .transition(.opacity)
  }
}

private struct ColdStartModifier: ViewModifier {
  let isLoading: Bool
  let delay: Duration

  @State private var showOverlay = false

  func body(content: Content) -> some View {
    content
      .overlay {
        if showOverlay { ColdStartOverlay() }
      }
      .task(id: isLoading) {
        showOverlay = false
        guard isLoading else { return }
        try? await Task.sleep(for: delay)
        if !Task.isCancelled && isLoading {
          withAnimation(.easeInOut) { showOverlay = true }
        }
      }
  }
}

extension View {
  /// Overlays a "Waking the server…" state after `delay` (default 3s) while
  /// `isLoading` stays true.
  func coldStart(isLoading: Bool, delay: Duration = .seconds(3)) -> some View {
    modifier(ColdStartModifier(isLoading: isLoading, delay: delay))
  }
}

#Preview {
  ColdStartOverlay()
}
