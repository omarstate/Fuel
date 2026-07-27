import SwiftUI

// A labeled horizontal progress bar for a single macro: name, value / goal, and
// a filled track. Numbers use monospaced digits + numeric-text transitions.
struct MacroBar: View {
  let label: LocalizedStringKey
  let value: Int
  let goal: Int
  var unit: LocalizedStringKey = "g"
  var fill: Color = .fuelCitrus
  var ink: Color = .fuelCitrusInk

  private var progress: Double { goal > 0 ? min(Double(value) / Double(goal), 1) : 0 }
  private var over: Bool { value > goal }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Text(label)
          .fuelEyebrow()
        Spacer()
        // The value/goal cluster stays LTR so the compound number never
        // bidi-reorders in Arabic; the outer row still mirrors. "37/165g".
        Text("\(Text("\(value)").foregroundStyle(Color.fuelInk))\(Text(verbatim: "/").foregroundStyle(Color.fuelSubtle))\(Text("\(goal)").foregroundStyle(Color.fuelSubtle))\(Text(unit).foregroundStyle(Color.fuelSubtle))")
          .contentTransition(.numericText())
          .font(.fuelMono(.subheadline, weight: 600))
          .environment(\.layoutDirection, .leftToRight)
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.fuelSubtle.opacity(0.16))
          // Bars keep their macro color even when over target (the web never
          // turns bars red — "over" is signalled by the pace line/pills).
          Capsule()
            .fill(fill)
            .frame(width: max(geo.size.width * progress, progress > 0 ? 6 : 0))
            .animation(.snappy, value: progress)
        }
      }
      .frame(height: 6)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(Text("\(value) of \(goal) \(Text(unit))"))
  }
}

#Preview {
  VStack(spacing: 18) {
    MacroBar(label: "Protein", value: 88, goal: 165, fill: MacroPalette.proteinFill, ink: MacroPalette.proteinInk)
    MacroBar(label: "Carbs", value: 140, goal: 220, fill: MacroPalette.carbsFill, ink: MacroPalette.carbsInk)
    MacroBar(label: "Fat", value: 82, goal: 70, fill: MacroPalette.fatFill, ink: MacroPalette.fatInk)
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
