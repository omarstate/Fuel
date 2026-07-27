import SwiftUI

// A catalog meal as a flat card (matches the web Library): name + kcal on top
// (a "~" prefix marks an AI estimate), a badges row (category volt-tint pill, an
// AI badge), the serving line as a mono uppercase eyebrow, then the P/C/F macro
// letters and a dark-ink "+ Add to today" pill. In the My-meals variant it also
// carries a "MY RECIPE" badge and inline Edit / Remove buttons. Content on
// FuelSurface — never glass.
struct MealCatalogCard: View {
  let meal: CatalogMeal
  /// Opens the meal detail (tap anywhere on the card body).
  var onOpen: () -> Void = {}
  /// Opens the AddToLogSheet for this meal.
  var onAdd: () -> Void = {}
  /// My-meals variant: shows the "MY RECIPE" badge + Edit/Remove buttons.
  var myRecipe: Bool = false
  var onEdit: (() -> Void)? = nil
  var onRemove: (() -> Void)? = nil

  private var kcalValue: Int { Int(meal.calories.rounded()) }

  private var kcalText: Text {
    if meal.aiSource == .estimate {
      return Text("~\(kcalValue)")
    }
    return Text("\(kcalValue)")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Text(meal.name)
          .font(.fuelBody(.body, weight: 600))
          .foregroundStyle(Color.fuelInk)
          .lineLimit(2)
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 1) {
          kcalText
            .font(.fuelMono(.title3, weight: 600))
            .foregroundStyle(Color.fuelInk)
          Text("kcal").fuelEyebrow()
        }
      }

      if meal.category != nil || meal.aiSource != nil || myRecipe {
        HStack(spacing: 6) {
          if myRecipe {
            PillBadge(title: "My recipe", tone: .citrus)
          }
          if let category = meal.category {
            PillBadge(title: "\(category.name)", tone: .volt)
          }
          aiBadge
        }
      }

      if let serving = meal.servingSize?.trimmingCharacters(in: .whitespaces), !serving.isEmpty {
        Text(serving).fuelEyebrow()
      }

      HStack(alignment: .center, spacing: 12) {
        MacroLetters(protein: Int(meal.protein.rounded()),
                     carbs: Int(meal.carbs.rounded()),
                     fat: Int(meal.fat.rounded()), size: 12, spacing: 12)
        Spacer(minLength: 8)
        addButton
      }

      if myRecipe {
        HStack(spacing: 18) {
          Spacer()
          if let onEdit {
            Button(action: onEdit) {
              Text("Edit")
                .font(.fuelBody(.footnote, weight: 600))
                .foregroundStyle(Color.fuelCitrusInk)
            }
            .buttonStyle(.plain)
          }
          if let onRemove {
            Button(action: onRemove) {
              Text("Remove")
                .font(.fuelBody(.footnote, weight: 600))
                .foregroundStyle(Color.fuelDestructive)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fuelCard()
    .contentShape(RoundedRectangle(cornerRadius: FuelRadius.card, style: .continuous))
    .onTapGesture { onOpen() }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(.isButton)
  }

  private var addButton: some View {
    Button(action: onAdd) {
      Label("Add to today", systemImage: "plus")
        .font(.fuelBody(.footnote, weight: 600))
        .foregroundStyle(Color.fuelBackground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.fuelInk, in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Add \(meal.name) to today")
  }

  @ViewBuilder
  private var aiBadge: some View {
    switch meal.aiSource {
    case .estimate:
      PillBadge(title: "AI estimate", tone: .gold)
    case .official:
      PillBadge(title: "AI", tone: .neutral)
    case nil:
      EmptyView()
    }
  }

  private var accessibilityLabel: String {
    var parts = [meal.name, "\(meal.aiSource == .estimate ? "about " : "")\(kcalValue) kilocalories"]
    parts.append("\(Int(meal.protein.rounded())) grams protein")
    parts.append("\(Int(meal.carbs.rounded())) grams carbs")
    parts.append("\(Int(meal.fat.rounded())) grams fat")
    if let category = meal.category { parts.append(category.name) }
    if myRecipe { parts.append("My recipe") }
    return parts.joined(separator: ", ")
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 12) {
      MealCatalogCard(meal: CatalogMeal(
        id: "1", name: "Koshari", description: nil, servingSize: "1 plate (450g)",
        calories: 720, protein: 22, carbs: 120, fat: 14,
        category: .init(id: "c", name: "AI Discovered", slug: "ai"),
        createdBy: "system", createdAt: Date(), aiSource: .estimate, sourceUrl: nil, macroRanges: nil
      ))
      MealCatalogCard(meal: CatalogMeal(
        id: "2", name: "McDonald's Big Tasty", description: nil, servingSize: "1 burger (351g)",
        calories: 793, protein: 44, carbs: 60, fat: 43,
        category: .init(id: "c", name: "AI Discovered", slug: "ai"),
        createdBy: nil, createdAt: Date(), aiSource: .official, sourceUrl: nil, macroRanges: nil
      ), myRecipe: true, onEdit: {}, onRemove: {})
    }
    .padding()
  }
  .background(Color.fuelBackground)
}
