import SwiftUI

// Animated circular progress ring with arbitrary center content. The trim
// animates on value changes; callers put a numeric readout in the center and
// pair it with `.contentTransition(.numericText())`.
struct MacroRing<Center: View>: View {
  /// 0...1 (values above 1 are clamped for the arc but callers can still show
  /// an over-target state in the center content / tint).
  let progress: Double
  var lineWidth: CGFloat = 11
  var tint: Color = .fuelOlive
  var trackColor: Color = Color.fuelSubtle.opacity(0.18)
  @ViewBuilder var center: () -> Center

  private var clamped: Double { min(max(progress, 0), 1) }

  var body: some View {
    ZStack {
      Circle()
        .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
      Circle()
        .trim(from: 0, to: clamped)
        .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .animation(.snappy, value: clamped)
      center()
    }
    .padding(lineWidth / 2)
  }
}

// The canonical calories ring used on Today and the History overview: the
// CONSUMED figure sits in the center (matching the web), the arc tracks
// consumed / target and warms to terracotta once over. `compact` shrinks the
// readout for the smaller overview ring.
struct CalorieRing: View {
  let consumed: Int
  let target: Int
  var lineWidth: CGFloat = 11
  var compact: Bool = false

  private var over: Bool { consumed > target }
  private var progress: Double { target > 0 ? Double(consumed) / Double(target) : 0 }

  var body: some View {
    MacroRing(progress: progress, lineWidth: lineWidth, tint: over ? .fuelOver : .fuelOlive) {
      VStack(spacing: 1) {
        Text("\(consumed)")
          .font(compact ? .fuelMetric : .fuelStatNumber)
          .foregroundStyle(Color.fuelInk)
          .contentTransition(.numericText())
          .minimumScaleFactor(0.6)
          .lineLimit(1)
        Text("kcal")
          .fuelEyebrow(size: compact ? 9 : 11)
      }
      .padding(.horizontal, compact ? 6 : 10)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Calories consumed"))
    .accessibilityValue(Text("\(consumed) of \(target)"))
  }
}

#Preview {
  VStack(spacing: 32) {
    CalorieRing(consumed: 960, target: 2200)
      .frame(width: 200, height: 200)
    CalorieRing(consumed: 2400, target: 2200, lineWidth: 10, compact: true)
      .frame(width: 96, height: 96)
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
