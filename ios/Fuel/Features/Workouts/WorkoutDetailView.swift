import SwiftUI

// One workout from the curated library, in full — the twin of
// `ExerciseDetailView`, which shows the same movement BEFORE it was added.
// Both are built from the components in ExerciseDetailComponents.swift (demo
// photo, attribute card, numbered instructions) so the screen a user sees while
// browsing and the screen they see afterwards are recognisably the same thing.
//
// The two differences are deliberate:
//   • no Add bar — this workout is already in the library, which is the only
//     way to reach this screen;
//   • the facts come from the `workouts` row (one primary muscle, equipment, a
//     sets × reps target) rather than the dataset's level/mechanic/force, which
//     the copy doesn't carry.
//
// Photos and instructions arrive from migration 0014. A library that predates
// it — or a hand-written workout from WorkoutForm — simply has empty arrays,
// and the photo box falls back to its "No demo photo" state while the steps
// section falls back to the description.
struct WorkoutDetailView: View {
  let workout: Workout

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        ExerciseDemoPhoto(urls: workout.imageURLs)
        header
        attributes
        about
        instructions
        types
      }
      .padding(20)
    }
    .background(Color.fuelBackground)
    .scrollEdgeEffectStyle(.soft, for: .top)
    .navigationTitle(workout.name)
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      PillBadge(title: "In library", tone: .workout)

      Text(workout.name)
        .font(.fuelTitle)
        .foregroundStyle(Color.fuelInk)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Attributes

  private var attributes: some View {
    let rows: [ExerciseAttributeCard.Row?] = [
      ExerciseAttributeCard.Row("muscle", "Muscle", workout.primaryMuscle),
      ExerciseAttributeCard.Row("equipment", "Equipment", workout.equipment),
      ExerciseAttributeCard.Row("target", "Target", workout.targetText),
    ]
    return ExerciseAttributeCard(rows: rows.compactMap { $0 })
  }

  // MARK: - About

  // Only when there are no instruction steps — see `standaloneDescription`,
  // since the description is cut from those same steps.
  @ViewBuilder
  private var about: some View {
    if let text = workout.standaloneDescription {
      VStack(alignment: .leading, spacing: 10) {
        Text("About").fuelEyebrow()
        // Catalog content, not UI copy — never routed through the string
        // catalog.
        Text(verbatim: text)
          .font(.fuelBody(.callout))
          .foregroundStyle(Color.fuelInk)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fuelCard()
      }
    }
  }

  // MARK: - Instructions

  // Hidden entirely when there is nothing to show AND the description already
  // covered it — an empty "Instructions / none" block under a paragraph that
  // says the same thing is noise.
  @ViewBuilder
  private var instructions: some View {
    if workout.standaloneDescription == nil {
      ExerciseInstructionsSection(
        steps: workout.instructions,
        emptyMessage: "No instructions for this workout."
      )
    }
  }

  // MARK: - Types

  @ViewBuilder
  private var types: some View {
    if !workout.categories.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("Types").fuelEyebrow()
        FlowLayout(spacing: 6, lineSpacing: 6) {
          ForEach(workout.categories, id: \.id) { category in
            PillBadge(title: "\(category.name)", tone: .neutral)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

#Preview("With photos") {
  NavigationStack {
    WorkoutDetailView(workout: Workout(
      id: "1",
      name: "Barbell Bench Press - Medium Grip",
      description: "Lie back on a flat bench.",
      primaryMuscle: "Chest",
      equipment: "Barbell",
      targetSets: 4,
      targetReps: "8-12",
      images: [
        "Barbell_Bench_Press_-_Medium_Grip/0.jpg",
        "Barbell_Bench_Press_-_Medium_Grip/1.jpg",
      ],
      instructions: [
        "Lie back on a flat bench. Using a medium width grip, lift the bar from the rack and hold it straight over you with your arms locked.",
        "From the starting position, breathe in and begin coming down slowly until the bar touches your middle chest.",
        "After a brief pause, push the bar back to the starting position as you breathe out.",
      ],
      categories: [
        .init(id: "a", name: "Push", slug: "push"),
        .init(id: "b", name: "Upper body", slug: "upper-body"),
      ],
      createdAt: Date()
    ))
  }
}

#Preview("Hand-written, no media") {
  NavigationStack {
    WorkoutDetailView(workout: Workout(
      id: "2",
      name: "Farmer's carry",
      description: "Pick up a heavy dumbbell in each hand and walk 40 metres without letting the shoulders round.",
      primaryMuscle: nil,
      equipment: "Dumbbells",
      targetSets: nil,
      targetReps: "to failure",
      categories: [],
      createdAt: Date()
    ))
  }
}
