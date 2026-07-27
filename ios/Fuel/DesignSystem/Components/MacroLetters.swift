import SwiftUI

// The shared "P 44  C 60  F 43" macro triple used on meal rows, day headers and
// catalog cards. Colored macro-ink letters + monospaced grams (no "g" suffix,
// matching the web). The cluster is pinned left-to-right so the compound numbers
// never bidi-reorder in Arabic. Content, never glass.
struct MacroLetters: View {
  let protein: Int
  let carbs: Int
  let fat: Int
  /// Point size for both the letter and the number.
  var size: CGFloat = 12
  /// Number color — subtle on rows, ink on bold day-total headers.
  var numberColor: Color = .fuelSubtle
  var spacing: CGFloat = 12

  var body: some View {
    HStack(spacing: spacing) {
      part("P", protein, MacroPalette.proteinInk)
      part("C", carbs, MacroPalette.carbsInk)
      part("F", fat, MacroPalette.fatInk)
    }
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(protein) grams protein, \(carbs) grams carbs, \(fat) grams fat")
  }

  private func part(_ letter: String, _ grams: Int, _ ink: Color) -> some View {
    HStack(spacing: 3) {
      Text(letter)
        .font(.fuelMono(size, weight: 700))
        .foregroundStyle(ink)
      Text("\(grams)")
        .font(.fuelMono(size, weight: 500))
        .foregroundStyle(numberColor)
        .contentTransition(.numericText())
        .lineLimit(1)
        .fixedSize()
    }
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    MacroLetters(protein: 44, carbs: 60, fat: 43)
    MacroLetters(protein: 149, carbs: 181, fat: 73, size: 13, numberColor: .fuelInk)
  }
  .padding()
  .background(Color.fuelBackground)
}
