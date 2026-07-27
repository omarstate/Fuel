import SwiftUI

// Presentation style for AsyncButton. Standalone so the style helper doesn't
// depend on AsyncButton's generic Label parameter.
enum AsyncButtonStyle {
  case glassProminent
  case glass
  case plain
}

// A button that runs an async throwing action, showing an in-place spinner and
// disabling itself while in flight so there are no dead taps or double-submits.
// Thrown errors are handed to `onError`; an optional success haptic fires when
// the action completes without throwing.
struct AsyncButton<Label: View>: View {
  var role: ButtonRole?
  var style: AsyncButtonStyle = .glassProminent
  var tint: Color = .fuelVolt
  var successHaptic: Bool = false
  let action: () async throws -> Void
  var onError: (Error) -> Void = { _ in }
  @ViewBuilder var label: () -> Label

  @State private var isRunning = false
  @State private var didSucceed = false

  var body: some View {
    Button(role: role) {
      guard !isRunning else { return }
      Task { await run() }
    } label: {
      ZStack {
        label()
          .opacity(isRunning ? 0 : 1)
        if isRunning {
          ProgressView()
            .controlSize(.small)
            .tint(style == .glassProminent ? Color.white : Color.fuelInk)
        }
      }
      .animation(.snappy, value: isRunning)
    }
    .disabled(isRunning)
    .modifier(AsyncButtonStyleModifier(style: style, tint: tint))
    .sensoryFeedback(.success, trigger: didSucceed)
  }

  private func run() async {
    isRunning = true
    defer { isRunning = false }
    do {
      try await action()
      if successHaptic { didSucceed.toggle() }
    } catch {
      onError(error)
    }
  }
}

private struct AsyncButtonStyleModifier: ViewModifier {
  let style: AsyncButtonStyle
  let tint: Color

  @ViewBuilder
  func body(content: Content) -> some View {
    switch style {
    case .glassProminent:
      content.buttonStyle(.glassProminent).tint(tint)
    case .glass:
      content.buttonStyle(.glass).tint(tint)
    case .plain:
      content.buttonStyle(.plain)
    }
  }
}

// Convenience for the common text-label primary button.
extension AsyncButton where Label == Text {
  init(
    _ title: LocalizedStringKey,
    role: ButtonRole? = nil,
    style: AsyncButtonStyle = .glassProminent,
    tint: Color = .fuelVolt,
    successHaptic: Bool = false,
    action: @escaping () async throws -> Void,
    onError: @escaping (Error) -> Void = { _ in }
  ) {
    self.role = role
    self.style = style
    self.tint = tint
    self.successHaptic = successHaptic
    self.action = action
    self.onError = onError
    self.label = { Text(title) }
  }
}

#Preview {
  VStack(spacing: 20) {
    AsyncButton("Save profile", successHaptic: true) {
      try? await Task.sleep(for: .seconds(1.2))
    }
    .frame(maxWidth: .infinity)

    AsyncButton("Secondary", style: .glass, tint: .fuelVoltInk) {
      try? await Task.sleep(for: .seconds(1))
    }
    .frame(maxWidth: .infinity)

    AsyncButton("Delete account", role: .destructive, style: .glass, tint: .fuelDestructive) {
      try? await Task.sleep(for: .seconds(1))
    }
    .frame(maxWidth: .infinity)
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
