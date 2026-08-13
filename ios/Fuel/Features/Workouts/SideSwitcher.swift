import SwiftUI

// The nutrition ↔ workouts side toggle — the iOS twin of the web sidebar's
// segmented mode switch. Compact enough to sit in a home-screen header row:
// two icon segments in a hairline capsule, the active one filled with its
// side's accent (green for nutrition, orange for workouts).
struct SideSwitcher: View {
  @Environment(AppState.self) private var app

  var body: some View {
    HStack(spacing: 2) {
      segment(.nutrition, systemImage: "fork.knife", label: "Nutrition")
      segment(.workouts, systemImage: "dumbbell.fill", label: "Workouts")
    }
    .padding(3)
    .background(Color.fuelInk.opacity(0.06), in: Capsule())
    .accessibilityElement(children: .contain)
  }

  private func segment(_ side: AppState.AppSide, systemImage: String, label: LocalizedStringKey) -> some View {
    let isActive = app.side == side
    return Button {
      guard !isActive else { return }
      withAnimation(.snappy) { app.side = side }
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(isActive ? Color.white : Color.fuelSubtle)
        .frame(width: 40, height: 28)
        .background(isActive ? fill(for: side) : Color.clear, in: Capsule())
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityAddTraits(isActive ? [.isSelected] : [])
  }

  private func fill(for side: AppState.AppSide) -> Color {
    switch side {
    case .nutrition: return .fuelVolt
    case .workouts: return .fuelWorkout
    }
  }
}

#Preview {
  SideSwitcher()
    .environment(AppState())
    .padding()
    .background(Color.fuelBackground)
}
