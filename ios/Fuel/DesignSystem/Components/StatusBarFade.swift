import SwiftUI

// Screens with hidden navigation bars (editorial mastheads) get no system
// scroll-edge treatment, so content collides with the clock/battery. This
// pins a background-colored fade over the status-bar area — visually matching
// the soft edge the system gives bar-backed screens like Coach.
private struct StatusBarFade: ViewModifier {
  func body(content: Content) -> some View {
    content.overlay(alignment: .top) {
      GeometryReader { geo in
        LinearGradient(
          stops: [
            .init(color: Color.fuelBackground, location: 0),
            .init(color: Color.fuelBackground.opacity(0.9), location: 0.55),
            .init(color: Color.fuelBackground.opacity(0), location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: geo.safeAreaInsets.top + 26)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
      }
    }
  }
}

extension View {
  /// Fade scrolling content out before it reaches the status bar. Use on every
  /// screen that hides the navigation bar.
  func statusBarFade() -> some View {
    modifier(StatusBarFade())
  }
}
