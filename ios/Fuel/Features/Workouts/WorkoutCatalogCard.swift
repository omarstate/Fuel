import SwiftUI

// One catalog exercise as a flat card, mirroring MealCatalogCard's structure so
// the two libraries read as the same screen: name, a mono uppercase
// "CHEST · BARBELL" eyebrow, the target-volume pill, a two-line description and
// the category chips. Content on FuelSurface — never glass.
struct WorkoutCatalogCard: View {
  let workout: Workout

  /// "4 × 8-12", or whichever half exists. Port of `setsReps` in
  /// workouts/workout-card.tsx — targetReps is free-form ("AMRAP"), so it is
  /// never parsed, only shown.
  private var targetText: String? {
    if let sets = workout.targetSets, let reps = workout.targetReps, !reps.isEmpty {
      return "\(sets) × \(reps)"
    }
    if let reps = workout.targetReps, !reps.isEmpty { return reps }
    if let sets = workout.targetSets { return String(localized: "\(sets) sets") }
    return nil
  }

  private var metaLine: String? {
    let parts = [workout.primaryMuscle, workout.equipment]
      .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(workout.name)
            .font(.fuelBody(.body, weight: 600))
            .foregroundStyle(Color.fuelInk)
            .lineLimit(2)
          if let metaLine {
            Text(metaLine).fuelEyebrow()
          }
        }
        Spacer(minLength: 8)
        if let targetText {
          PillBadge(title: "\(targetText)", tone: .workout)
        }
      }

      if let description = workout.description?.trimmingCharacters(in: .whitespacesAndNewlines),
         !description.isEmpty {
        Text(description)
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
          .lineLimit(2)
      }

      // KNOWN CAVEAT: when the list is filtered by category, the API embeds only
      // the MATCHED category on each row, so a workout tagged Push+Pull shows
      // one chip under a filter and both under "All". That is the backend's
      // shape (workout.model.js filters the embed), not a bug here.
      if !workout.categories.isEmpty {
        FlowLayout(spacing: 6, lineSpacing: 6) {
          ForEach(workout.categories, id: \.id) { category in
            CategoryChip(name: category.name)
          }
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fuelCard()
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  private var accessibilityLabel: String {
    var parts = [workout.name]
    if let metaLine { parts.append(metaLine) }
    if let targetText { parts.append(targetText) }
    return parts.joined(separator: ", ")
  }
}

// A static, hairline-outlined tag — the non-interactive twin of the Library's
// filter chips, so a card's categories never look tappable.
private struct CategoryChip: View {
  let name: String

  var body: some View {
    Text(name)
      .font(.fuelMono(.caption2, weight: 500))
      .textCase(.uppercase)
      .tracking(0.6)
      .foregroundStyle(Color.fuelSubtle)
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .overlay(
        Capsule().strokeBorder(Color.fuelInk.opacity(0.12), lineWidth: 1)
      )
  }
}

extension Workout {
  // Neutral shape behind the redacted first-load skeleton cards.
  static let placeholder = Workout(
    id: "placeholder",
    name: "Workout name",
    description: "A short description of how the movement is performed.",
    primaryMuscle: "Muscle",
    equipment: "Equipment",
    targetSets: 4,
    targetReps: "8-12",
    categories: [.init(id: "c", name: "Category", slug: "category")],
    createdAt: Date()
  )
}

#Preview {
  ScrollView {
    VStack(spacing: 12) {
      WorkoutCatalogCard(workout: Workout(
        id: "1", name: "Barbell bench press",
        description: "Flat bench, shoulder blades retracted, bar to mid-chest and press back over the shoulders.",
        primaryMuscle: "Chest", equipment: "Barbell",
        targetSets: 4, targetReps: "8-12",
        categories: [
          .init(id: "a", name: "Push", slug: "push"),
          .init(id: "b", name: "Upper body", slug: "upper"),
        ],
        createdAt: Date()
      ))
      WorkoutCatalogCard(workout: Workout(
        id: "2", name: "Farmer's carry",
        description: nil,
        primaryMuscle: nil, equipment: "Dumbbells",
        targetSets: nil, targetReps: "to failure",
        categories: [],
        createdAt: Date()
      ))
      WorkoutCatalogCard(workout: .placeholder)
        .redacted(reason: .placeholder)
    }
    .padding()
  }
  .background(Color.fuelBackground)
}
