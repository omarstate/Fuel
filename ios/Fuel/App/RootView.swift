import SwiftUI

// Top-level surface switch. Smooth cross-fades between phases.
struct RootView: View {
  @Environment(AppState.self) private var app

  var body: some View {
    Group {
      switch app.phase {
      case .loading:
        SplashView()
      case .signedOut:
        AuthView()
      case .needsOnboarding:
        OnboardingView()
      case .ready:
        MainTabView()
      }
    }
    .animation(.smooth(duration: 0.35), value: app.phase)
    .tint(.fuelVolt)
    // The identity is dark-only: lock the whole app to the charcoal palette so
    // system chrome (sheets, forms, pickers, nav bars) matches the tokens.
    .preferredColorScheme(.dark)
  }
}

// Branded launch splash: bolt + Fuel wordmark with a subtle breathing
// animation. Also carries bootstrap error / cold-start UX.
struct SplashView: View {
  @Environment(AppState.self) private var app
  @State private var animate = false

  var body: some View {
    ZStack {
      Color.fuelBackground.ignoresSafeArea()

      VStack(spacing: 16) {
        Image("FuelLogo")
          .resizable()
          .scaledToFit()
          .frame(width: 96, height: 96)
          .accessibilityHidden(true)
          .scaleEffect(animate ? 1.06 : 0.94)
          .opacity(animate ? 1 : 0.7)
          .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: animate)

        Text("Fuel")
          .font(.fuelHeading(44, weight: 700, relativeTo: .largeTitle))
          .foregroundStyle(Color.fuelInk)
      }

      if app.bootstrapError != nil {
        VStack {
          Spacer()
          if let error = app.bootstrapError {
            ErrorBanner(error: error, onRetry: {
              Task { await app.loadUserData() }
            })
            .padding()
          }
        }
      }
    }
    .coldStart(isLoading: app.isBootstrapping && app.bootstrapError == nil)
    .onAppear { animate = true }
  }
}
