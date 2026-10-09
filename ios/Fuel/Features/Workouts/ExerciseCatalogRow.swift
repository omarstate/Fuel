import SwiftUI

// One dataset exercise in the "Browse exercises" sheet: demo thumbnail, name,
// a "CHEST · BARBELL · BEGINNER" eyebrow, and the add control.
//
// The whole row is NOT a button, unlike ExercisePickerSheet's rows: the only
// action is Add, and a full-width tap target that silently writes to the shared
// catalog is too easy to trigger while scrolling. The add button carries its own
// state (idle → spinner → "In library") per DESIGN.md's "every async control
// shows its state in place".
struct ExerciseCatalogRow: View {
  let exercise: CatalogExercise
  let isInLibrary: Bool
  let isAdding: Bool
  let onAdd: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      thumbnail
      VStack(alignment: .leading, spacing: 3) {
        Text(exercise.name)
          .font(.fuelBody(.body, weight: 600))
          .foregroundStyle(Color.fuelInk)
          .lineLimit(2)
        if let metaLine = exercise.metaLine {
          Text(metaLine).fuelEyebrow()
        }
      }
      Spacer(minLength: 8)
      addControl
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .fuelCard()
  }

  // MARK: - Thumbnail

  // The dataset's photos are large JPEGs on raw.githubusercontent.com, so this
  // is a plain AsyncImage with a placeholder on every non-success phase — three
  // of ~870 entries ship no image at all, and a failed fetch must look the same
  // as that rather than leaving a hole.
  private var thumbnail: some View {
    Group {
      if let url = exercise.imageURL {
        AsyncImage(url: url, transaction: Transaction(animation: .snappy)) { phase in
          switch phase {
          case .success(let image):
            image.resizable().scaledToFill()
          case .empty:
            ProgressView().controlSize(.small)
          default:
            placeholderGlyph
          }
        }
      } else {
        placeholderGlyph
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

  private var placeholderGlyph: some View {
    Image(systemName: "figure.strengthtraining.traditional")
      .font(.system(size: 20))
      .foregroundStyle(Color.fuelSubtle.opacity(0.6))
  }

  // MARK: - Add control

  @ViewBuilder
  private var addControl: some View {
    if isInLibrary {
      // A label, not a disabled button: there is nothing left to tap, and the
      // tick is the confirmation of the tap that just happened.
      HStack(spacing: 4) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 13, weight: .semibold))
        Text("In library")
          .font(.fuelMono(.caption, weight: 600))
      }
      .foregroundStyle(Color.fuelWorkoutInk)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.fuelWorkout.opacity(0.16), in: Capsule())
      .transition(.opacity.combined(with: .scale(scale: 0.9)))
      .accessibilityLabel(Text("\(exercise.name), already in your library"))
    } else {
      Button(action: onAdd) {
        ZStack {
          Image(systemName: "plus")
            .font(.system(size: 15, weight: .bold))
            .opacity(isAdding ? 0 : 1)
          if isAdding {
            ProgressView().controlSize(.small).tint(Color.white)
          }
        }
        .frame(width: 44, height: 44)
        .contentShape(.rect)
      }
      .buttonStyle(.glassProminent)
      .tint(.fuelWorkout)
      .disabled(isAdding)
      .accessibilityLabel(Text("Add \(exercise.name) to your library"))
    }
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 10) {
      ExerciseCatalogRow(
        exercise: .preview,
        isInLibrary: false,
        isAdding: false,
        onAdd: {}
      )
      ExerciseCatalogRow(
        exercise: .preview,
        isInLibrary: false,
        isAdding: true,
        onAdd: {}
      )
      ExerciseCatalogRow(
        exercise: .preview,
        isInLibrary: true,
        isAdding: false,
        onAdd: {}
      )
      ExerciseCatalogRow(exercise: .placeholder, isInLibrary: false, isAdding: false, onAdd: {})
        .redacted(reason: .placeholder)
    }
    .padding()
  }
  .background(Color.fuelBackground)
}

extension CatalogExercise {
  // Neutral shape behind the redacted first-load skeleton rows.
  static let placeholder = CatalogExercise(
    slug: "placeholder",
    name: "Exercise name",
    category: "strength",
    level: "beginner",
    mechanic: "compound",
    force: "push",
    equipment: "barbell",
    primaryMuscles: ["chest"],
    secondaryMuscles: [],
    instructions: [],
    images: [],
    inLibrary: false
  )

  static let preview = CatalogExercise(
    slug: "Barbell_Bench_Press_-_Medium_Grip",
    name: "Barbell Bench Press - Medium Grip",
    category: "strength",
    level: "beginner",
    mechanic: "compound",
    force: "push",
    equipment: "barbell",
    primaryMuscles: ["chest"],
    secondaryMuscles: ["shoulders", "triceps"],
    instructions: ["Lie back on a flat bench."],
    images: [],
    inLibrary: false
  )
}
