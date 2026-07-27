import SwiftUI

// A compact metric tile sitting on FuelSurface (content, never glass). The
// value animates with a numeric-text content transition when it changes.
struct StatTile: View {
  let label: LocalizedStringKey
  let value: String
  var unit: LocalizedStringKey?
  var systemImage: String?
  var tint: Color = .fuelInk

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 5) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
        }
        Text(label)
          .fuelEyebrow()
      }
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value)
          .font(.fuelMetric)
          .foregroundStyle(Color.fuelInk)
          .contentTransition(.numericText())
        if let unit {
          Text(unit)
            .font(.fuelMono(.caption, weight: 600))
            .foregroundStyle(Color.fuelSubtle)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .fuelCard(radius: 16)
  }
}

#Preview {
  HStack(spacing: 12) {
    StatTile(label: "Remaining", value: "1,240", unit: "kcal", systemImage: "flame.fill", tint: .fuelVoltInk)
    StatTile(label: "Protein", value: "88", unit: "g", systemImage: "circle.fill", tint: .fuelCitrusInk)
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
