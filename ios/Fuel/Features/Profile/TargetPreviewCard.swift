import SwiftUI

// Live target preview: a calorie ring + macro bars computed from the current
// form values via TargetMath. Numbers animate as fields change.
struct TargetPreviewCard: View {
  let targets: Targets
  var direction: Direction?
  var title: LocalizedStringKey = "Your daily targets"

  var body: some View {
    VStack(spacing: 20) {
      HStack {
        SectionHeader(title, eyebrow: directionEyebrow)
        Spacer(minLength: 0)
      }

      HStack(spacing: 20) {
        MacroRing(progress: 1, lineWidth: 11, tint: .fuelOlive) {
          VStack(spacing: 0) {
            Text("\(targets.calories)")
              .font(.fuelMetric)
              .foregroundStyle(Color.fuelInk)
              .contentTransition(.numericText())
            Text("kcal")
              .fuelEyebrow()
          }
        }
        .frame(width: 116, height: 116)

        VStack(spacing: 12) {
          MacroBar(label: "Protein", value: targets.protein, goal: targets.protein,
                   fill: MacroPalette.proteinFill, ink: MacroPalette.proteinInk)
          MacroBar(label: "Carbs", value: targets.carbs, goal: targets.carbs,
                   fill: MacroPalette.carbsFill, ink: MacroPalette.carbsInk)
          MacroBar(label: "Fat", value: targets.fat, goal: targets.fat,
                   fill: MacroPalette.fatFill, ink: MacroPalette.fatInk)
        }
      }
    }
    .padding(20)
    .fuelCard(radius: 20)
    .animation(.snappy, value: targets)
  }

  private var directionEyebrow: LocalizedStringKey? {
    switch direction {
    case .cut: return "Cutting"
    case .bulk: return "Bulking"
    case .maintain: return "Maintaining"
    case .none: return nil
    }
  }
}

#Preview {
  VStack(spacing: 16) {
    TargetPreviewCard(targets: TargetMath.defaultTargets, direction: .maintain)
    TargetPreviewCard(targets: Targets(calories: 1800, protein: 144, carbs: 158, fat: 50), direction: .cut)
  }
  .padding()
  .background(Color.fuelBackground)
}
