import SwiftUI
import UIKit

@main
struct FuelApp: App {
  @State private var app = AppState()

  init() {
    Self.configureNavigationBarTypography()
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(app)
        // Default body face for all text that doesn't set its own font — keeps
        // form labels, list rows and plain copy on Google Sans Flex (Cairo in
        // Arabic) rather than San Francisco, matching the web app.
        .font(.fuelBody(.body))
        .task { app.start() }
    }
  }

  // Brand the system navigation bars (large + inline titles) with Google Sans
  // Flex. We only override the title fonts — backgrounds stay the system's so
  // Liquid Glass / transparent-at-top scroll behavior is preserved.
  private static func configureNavigationBarTypography() {
    let largeTitle = [NSAttributedString.Key.font: FuelFontFamily.uiFont(family: FuelFontFamily.display, size: 32, weight: 700)]
    let inlineTitle = [NSAttributedString.Key.font: FuelFontFamily.uiFont(family: FuelFontFamily.display, size: 17, weight: 600)]

    let standard = UINavigationBarAppearance()
    standard.configureWithDefaultBackground()
    standard.largeTitleTextAttributes = largeTitle
    standard.titleTextAttributes = inlineTitle

    let scrollEdge = UINavigationBarAppearance()
    scrollEdge.configureWithTransparentBackground()
    scrollEdge.largeTitleTextAttributes = largeTitle
    scrollEdge.titleTextAttributes = inlineTitle

    let proxy = UINavigationBar.appearance()
    proxy.standardAppearance = standard
    proxy.compactAppearance = standard
    proxy.scrollEdgeAppearance = scrollEdge
  }
}
