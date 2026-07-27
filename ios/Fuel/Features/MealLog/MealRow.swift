import SwiftUI

// A single meal-log row shared by Today and History: name, a "MEALTYPE · SERVING"
// mono eyebrow sub-line, the P/C/F macro letters in their inks, and a monospaced
// kcal readout. Content, never glass. Sits on a `.fuelSurface` list row.
struct MealRow: View {
  let meal: LoggedMeal
  /// When set, the row shows an explicit trailing trash button (in addition to
  /// whatever swipe/context actions the list attaches).
  var onDelete: (() -> Void)? = nil

  // "DINNER · 1 BURGER (351G)" — meal type, then serving when present. Uppercased
  // by the eyebrow modifier.
  private var subline: String {
    if let serving = meal.servingSize?.trimmingCharacters(in: .whitespaces), !serving.isEmpty {
      return "\(meal.mealType.label) · \(serving)"
    }
    return meal.mealType.label
  }

  var body: some View {
    HStack(alignment: .center, spacing: 4) {
      // Two lines instead of one crowded row so big numbers (4-digit kcal,
      // 3-digit protein) never collide with the name:
      //   KFC 6 Pieces Original Recipe          1,410 kcal
      //   DINNER · 6 PIECES (519G)             P 123 C 43 F 84
      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(meal.name)
            .font(.fuelBody(.body, weight: 500))
            .foregroundStyle(Color.fuelInk)
            .lineLimit(1)
          Spacer(minLength: 8)
          Text("\(meal.calories)")
            .font(.fuelMono(.headline, weight: 600))
            .foregroundStyle(Color.fuelInk)
            .contentTransition(.numericText())
            .lineLimit(1)
            .fixedSize()
          Text("kcal").fuelEyebrow()
        }
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(subline)
            .fuelEyebrow()
            .lineLimit(1)
          Spacer(minLength: 8)
          MacroLetters(protein: meal.protein, carbs: meal.carbs, fat: meal.fat, size: 12, spacing: 10)
            .fixedSize()
        }
      }
      if let onDelete {
        Button(action: onDelete) {
          Image(systemName: "trash")
            .font(.body.weight(.medium))
            .foregroundStyle(Color.fuelSubtle)
            // Comfortable thumb target: full 44pt minimum in both directions,
            // bleeding into the row's edge padding rather than shrinking.
            .frame(width: 44, height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Remove \(meal.name)"))
        .padding(.trailing, -12)
        .padding(.vertical, -6)
      }
    }
    .padding(.vertical, 6)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(meal.name), \(meal.calories) kilocalories, \(meal.protein) grams protein, \(meal.carbs) grams carbs, \(meal.fat) grams fat")
  }
}

#Preview {
  List {
    MealRow(meal: LoggedMeal(userId: UUID(), name: "Koshari", mealType: .lunch, servingSize: "1 plate (450g)", calories: 720, protein: 22, carbs: 120, fat: 14))
    MealRow(meal: LoggedMeal(userId: UUID(), name: "Grilled chicken", mealType: .dinner, calories: 210, protein: 38, carbs: 0, fat: 6))
    // The overflow stress case: 4-digit kcal + 3-digit protein + long name +
    // long serving + delete button must all coexist without wrapping.
    MealRow(
      meal: LoggedMeal(userId: UUID(), name: "KFC 6 Pieces Original Recipe", mealType: .dinner, servingSize: "6 pieces (519g)", calories: 1410, protein: 123, carbs: 43, fat: 84),
      onDelete: {}
    )
  }
  .listStyle(.plain)
}
