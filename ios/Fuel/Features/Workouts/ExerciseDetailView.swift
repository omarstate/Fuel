import SwiftUI

// One dataset exercise in full, pushed from the "Browse exercises" sheet. The
// row answers "is this the movement I meant?"; this answers "how do I do it?"
//
// It takes the `CatalogExercise` it was pushed with rather than refetching by
// slug: the list endpoint already returns `instructions` and `images` in full
// (backend `rowToExercise` maps every column, and `listExercises` selects "*"),
// so a detail fetch would be a round trip for data already in hand.
//
// The view model comes along so the Add button is the SAME action and the SAME
// lifecycle as the row's — `addingSlug` drives the spinner and `isInLibrary`
// the "In library" state, which means adding here updates the row behind it for
// free (both read the one `@Observable`).
struct ExerciseDetailView: View {
  let exercise: CatalogExercise
  let model: ExerciseCatalogViewModel

  private var isInLibrary: Bool { model.isInLibrary(exercise) }
  private var isAdding: Bool { model.addingSlug == exercise.slug }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        ExerciseDemoPhoto(urls: exercise.imageURLs)

        // The add can only fail from here or from the list; the list's own
        // banner is behind this push, so it has to be repeated.
        if let error = model.error {
          ErrorBanner(error: error, onDismiss: { model.error = nil })
        }

        header
        muscles
        attributes
        instructions
      }
      .padding(20)
      .animation(.snappy, value: model.addedSlugs)
    }
    .background(Color.fuelBackground)
    .scrollEdgeEffectStyle(.soft, for: .top)
    .navigationTitle(exercise.name)
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom) { addBar }
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Dataset category, title-cased. Free text by design, so it renders as a
      // pill rather than switching over a closed set.
      PillBadge(title: "\(CatalogExercise.titleCased(exercise.category))", tone: .workout)

      Text(exercise.name)
        .font(.fuelTitle)
        .foregroundStyle(Color.fuelInk)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Muscles

  @ViewBuilder
  private var muscles: some View {
    let primary = exercise.primaryMuscles.filter { !$0.isEmpty }
    let secondary = exercise.secondaryMuscles.filter { !$0.isEmpty }

    if !primary.isEmpty || !secondary.isEmpty {
      VStack(alignment: .leading, spacing: 16) {
        if !primary.isEmpty {
          musclePills("Targets", primary, tone: .workout)
        }
        if !secondary.isEmpty {
          musclePills("Also works", secondary, tone: .neutral)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func musclePills(
    _ title: LocalizedStringKey,
    _ values: [String],
    tone: PillBadge.Tone
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).fuelEyebrow()
      // Muscle names are variable-width and a long one ("Lower Back") must wrap
      // rather than scroll off, which is exactly FlowLayout's job.
      FlowLayout(spacing: 6, lineSpacing: 6) {
        ForEach(values, id: \.self) { value in
          PillBadge(title: "\(CatalogExercise.titleCased(value))", tone: tone)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Attributes

  // The four scalar dataset fields, each optional. WorkoutDetailView fills the
  // same card with the three the library row carries.
  private var attributes: some View {
    let rows: [ExerciseAttributeCard.Row?] = [
      ExerciseAttributeCard.Row("equipment", "Equipment", exercise.equipment.map(CatalogExercise.titleCased)),
      ExerciseAttributeCard.Row("level", "Level", exercise.level.map(CatalogExercise.titleCased)),
      ExerciseAttributeCard.Row("movement", "Movement", exercise.mechanic.map(CatalogExercise.titleCased)),
      ExerciseAttributeCard.Row("force", "Force", exercise.force.map(CatalogExercise.titleCased)),
    ]
    return ExerciseAttributeCard(rows: rows.compactMap { $0 })
  }

  // MARK: - Instructions

  private var instructions: some View {
    ExerciseInstructionsSection(
      steps: exercise.instructions,
      emptyMessage: "No instructions for this exercise."
    )
  }

  // MARK: - Add bar

  // Pinned to the bottom safe area so the one action on this screen is never a
  // scroll away, however long the instructions run. Glass, because it floats
  // over content — the cards below it stay opaque.
  @ViewBuilder
  private var addBar: some View {
    Group {
      if isInLibrary {
        // A label, not a disabled button — the same reasoning as the row: there
        // is nothing left to tap, and the tick confirms the tap that happened.
        HStack(spacing: 6) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 15, weight: .semibold))
          Text("In library")
            .font(.fuelBody(.headline, weight: 600))
        }
        .foregroundStyle(Color.fuelWorkoutInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.fuelWorkout.opacity(0.16), in: Capsule())
        .transition(.opacity)
      } else {
        Button {
          Task { await model.add(exercise) }
        } label: {
          ZStack {
            Label("Add to library", systemImage: "plus")
              .font(.fuelBody(.headline, weight: 600))
              .opacity(isAdding ? 0 : 1)
            if isAdding {
              ProgressView().controlSize(.small).tint(Color.white)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .tint(.fuelWorkout)
        .disabled(isAdding)
        .accessibilityLabel(Text("Add \(exercise.name) to your library"))
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 6)
    .animation(.snappy, value: isAdding)
  }
}

#Preview("With photos") {
  NavigationStack {
    ExerciseDetailView(
      exercise: CatalogExercise(
        slug: "Barbell_Bench_Press_-_Medium_Grip",
        name: "Barbell Bench Press - Medium Grip",
        category: "strength",
        level: "beginner",
        mechanic: "compound",
        force: "push",
        equipment: "barbell",
        primaryMuscles: ["chest"],
        secondaryMuscles: ["shoulders", "triceps"],
        instructions: [
          "Lie back on a flat bench. Using a medium width grip, lift the bar from the rack and hold it straight over you with your arms locked. This will be your starting position.",
          "From the starting position, breathe in and begin coming down slowly until the bar touches your middle chest.",
          "After a brief pause, push the bar back to the starting position as you breathe out.",
          "Repeat the movement for the prescribed amount of repetitions.",
        ],
        images: [
          "Barbell_Bench_Press_-_Medium_Grip/0.jpg",
          "Barbell_Bench_Press_-_Medium_Grip/1.jpg",
        ],
        inLibrary: false
      ),
      model: ExerciseCatalogViewModel()
    )
  }
}

#Preview("No photos") {
  NavigationStack {
    ExerciseDetailView(exercise: .preview, model: ExerciseCatalogViewModel())
  }
}
