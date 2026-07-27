import SwiftUI

// The Today hero — a direct port of the web "activity rings" summary. Two
// concentric rings (green outer = calories, blue inner = protein), the two
// headline numbers stacked at the center, a legend naming each ring, then a
// three-up strip for the remaining macros + kcal left.
//
// The big readouts use Google Sans Flex (fuelHeading), NOT mono, so they feel
// like the reference — the friendly, rounded activity-ring numerals. Everything
// sits bare on the charcoal canvas (no card), exactly like the web.
struct ActivityRings: View {
  let consumed: Int
  let calorieTarget: Int
  let protein: Int
  let proteinTarget: Int
  let carbs: Int
  let carbTarget: Int
  let fat: Int
  let fatTarget: Int

  private var over: Bool { consumed > calorieTarget }
  private var calProgress: Double { calorieTarget > 0 ? Double(consumed) / Double(calorieTarget) : 0 }
  private var proProgress: Double { proteinTarget > 0 ? Double(protein) / Double(proteinTarget) : 0 }

  var body: some View {
    VStack(spacing: 22) {
      rings
      caloriesCard
      HStack(spacing: 10) {
        macroCard(systemImage: "bolt.fill", tint: .fuelBlue, value: protein, goal: proteinTarget, label: "Protein")
        macroCard(systemImage: "leaf.fill", tint: .fuelGoldInk, value: carbs, goal: carbTarget, label: "Carbs")
        macroCard(systemImage: "drop.fill", tint: .fuelVoltInk, value: fat, goal: fatTarget, label: "Fat")
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: Rings + centered headline numbers

  private var rings: some View {
    ZStack {
      ring(progress: calProgress, tint: .fuelOlive, diameter: 216, lineWidth: 15)  // calories, green
      ring(progress: proProgress, tint: .fuelBlue, diameter: 158, lineWidth: 15)   // protein, blue
      VStack(spacing: 2) {
        Text("\(consumed)")
          .font(.fuelHeading(52, weight: 700, relativeTo: .largeTitle))
          .foregroundStyle(Color.fuelOlive)
          .contentTransition(.numericText())
          .minimumScaleFactor(0.5)
          .lineLimit(1)
        Text("\(protein)")
          .font(.fuelHeading(28, weight: 700, relativeTo: .title))
          .foregroundStyle(Color.fuelBlue)
          .contentTransition(.numericText())
          .lineLimit(1)
      }
      .frame(width: 130)
    }
    .frame(width: 240, height: 240)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Today's rings")
    .accessibilityValue("\(consumed) of \(calorieTarget) calories, \(protein) of \(proteinTarget) grams protein")
  }

  private func ring(progress: Double, tint: Color, diameter: CGFloat, lineWidth: CGFloat) -> some View {
    ZStack {
      Circle()
        .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
      Circle()
        .trim(from: 0, to: min(max(progress, 0), 1))
        .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .shadow(color: tint.opacity(0.45), radius: 5)
        .animation(.snappy, value: progress)
    }
    .frame(width: diameter, height: diameter)
  }

  // MARK: Calories — its own main card

  private var caloriesCard: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 7) {
        Image(systemName: "flame.fill")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(over ? Color.fuelOver : Color.fuelOlive)
        Text("Calories").fuelEyebrow(size: 10)
        Spacer()
        Text("of \(calorieTarget) kcal")
          .font(.fuelMono(.caption2, weight: 500))
          .foregroundStyle(Color.fuelSubtle)
          .environment(\.layoutDirection, .leftToRight)
      }
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text("\(consumed)")
          .font(.fuelHeading(30, weight: 700, relativeTo: .title))
          .foregroundStyle(over ? Color.fuelOver : Color.fuelOlive)
          .contentTransition(.numericText())
          .minimumScaleFactor(0.6)
          .lineLimit(1)
        Text("kcal")
          .font(.fuelMono(.footnote, weight: 600))
          .foregroundStyle(Color.fuelSubtle)
      }
      progressBar(value: consumed, goal: calorieTarget, tint: over ? .fuelOver : .fuelOlive)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .fuelCard(radius: 18)
  }

  // MARK: Macro cards (protein / carbs / fat, side by side)

  private func macroCard(systemImage: String, tint: Color, value: Int, goal: Int, label: LocalizedStringKey) -> some View {
    VStack(spacing: 8) {
      Image(systemName: systemImage)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(tint)
      HStack(alignment: .firstTextBaseline, spacing: 1) {
        Text("\(value)")
          .font(.fuelHeading(23, weight: 700, relativeTo: .title2))
          .foregroundStyle(tint)
          .contentTransition(.numericText())
          .minimumScaleFactor(0.6)
          .lineLimit(1)
        Text("g")
          .font(.fuelMono(.caption2, weight: 600))
          .foregroundStyle(Color.fuelSubtle)
      }
      Text(label).fuelEyebrow(size: 9)
      progressBar(value: value, goal: goal, tint: tint)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 13)
    .padding(.horizontal, 10)
    .fuelCard(radius: 16)
  }

  // MARK: Shared slim progress bar

  private func progressBar(value: Int, goal: Int, tint: Color) -> some View {
    let progress = goal > 0 ? min(Double(value) / Double(goal), 1) : 0
    return GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.white.opacity(0.08))
        Capsule()
          .fill(tint)
          .frame(width: max(geo.size.width * progress, progress > 0 ? 5 : 0))
          .animation(.snappy, value: progress)
      }
    }
    .frame(height: 4)
  }
}

#Preview {
  ActivityRings(consumed: 1772, calorieTarget: 2200, protein: 120, proteinTarget: 150,
                carbs: 210, carbTarget: 252, fat: 60, fatTarget: 70)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.fuelBackground)
}
