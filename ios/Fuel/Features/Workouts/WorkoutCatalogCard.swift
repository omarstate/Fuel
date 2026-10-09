import SwiftUI

// One catalog exercise as a flat card, mirroring MealCatalogCard's structure so
// the two libraries read as the same screen: name, a mono uppercase
// "CHEST · BARBELL" eyebrow, the target-volume pill, a two-line description and
// the category chips. Content on FuelSurface — never glass.
struct WorkoutCatalogCard: View {
  let workout: Workout
  /// Opens the workout's detail. Defaulted to nil so the redacted skeleton
  /// cards and the previews stay one-liners — and so a card with nowhere to go
  /// shows no chevron and takes no taps.
  var onOpen: (() -> Void)? = nil

  private var targetText: String? { workout.targetText }
  private var metaLine: String? { workout.metaLine }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        // Only when the workout was added from the exercise catalog AND
        // migration 0014 has run; otherwise the row keeps its original
        // text-only layout rather than reserving an empty box.
        if let url = workout.imageURLs.first {
          thumbnail(url)
        }
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
        if onOpen != nil {
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.fuelSubtle.opacity(0.7))
            .padding(.top, 2)
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
    // Whole-card tap, unlike ExerciseCatalogRow's split regions: a library card
    // has no competing write action to protect, and the detail is read-only.
    .contentShape(.rect)
    .onTapGesture { onOpen?() }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(onOpen == nil ? [] : .isButton)
    .accessibilityHint(onOpen == nil ? Text("") : Text("Shows workout details"))
  }

  // MARK: - Thumbnail

  // Same 56pt box, 12pt corner and hairline as ExerciseCatalogRow's, so the
  // browse sheet and the library read as one set of photos. A failed fetch
  // falls back to the same glyph as "no photo at all".
  private func thumbnail(_ url: URL) -> some View {
    AsyncImage(url: url, transaction: Transaction(animation: .snappy)) { phase in
      switch phase {
      case .success(let image):
        image.resizable().scaledToFill()
      case .empty:
        ProgressView().controlSize(.small)
      default:
        Image(systemName: "figure.strengthtraining.traditional")
          .font(.system(size: 20))
          .foregroundStyle(Color.fuelSubtle.opacity(0.6))
      }
    }
    .frame(width: 56, height: 56)
    .background(Color.fuelInk.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
        .strokeBorder(Color.fuelInk.opacity(0.06), lineWidth: 1)
    )
    .accessibilityHidden(true)
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
