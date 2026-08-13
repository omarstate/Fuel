import SwiftUI

// The read-only rendering of a finished session's exercises — a port of the
// `editable={false}` branch of workouts/session/session-exercise-list.tsx.
//
// The live session deliberately does NOT reuse this: while training you tap set
// pills to edit them (ActiveExerciseCard), whereas history is a receipt. Keeping
// them separate means neither screen carries the other's affordances.
struct SessionExerciseList: View {
  let exercises: [SessionExerciseWithSets]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(exercises) { exercise in
        ExerciseCard(exercise: exercise)
      }
    }
  }
}

private struct ExerciseCard: View {
  let exercise: SessionExerciseWithSets

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(exercise.name)
          .font(.fuelBody(.body, weight: 600))
          .foregroundStyle(Color.fuelInk)
        // A custom exercise never came from the catalog, so nothing links back
        // to a description — the pill is the only cue it was typed by hand.
        if exercise.workoutId == nil {
          PillBadge(title: "Custom", tone: .neutral)
        }
        Spacer(minLength: 0)
      }

      if exercise.sets.isEmpty {
        Text("No sets logged.")
          .font(.fuelBody(.footnote))
          .foregroundStyle(Color.fuelSubtle)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
            if index > 0 {
              Divider().overlay(Color.fuelInk.opacity(0.06))
            }
            SetRow(set: set, index: index + 1)
          }
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fuelCard()
  }
}

// One logged set: "#2   82.5 × 8" with an optional note underneath. The numbers
// are pinned left-to-right so an Arabic layout still reads weight-then-reps,
// matching SetPill on the live screen.
private struct SetRow: View {
  let set: SessionSet
  let index: Int

  private var weightText: String {
    guard let weight = set.weight else { return "—" }
    return DurationFormat.weight(weight)
  }

  private var repsText: String {
    guard let reps = set.reps else { return "—" }
    return String(reps)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 10) {
        Text("#\(index)")
          .font(.fuelMono(.caption, weight: 500))
          .foregroundStyle(Color.fuelSubtle)
          .frame(minWidth: 26, alignment: .leading)
        HStack(spacing: 4) {
          Text(weightText)
          Text("×").foregroundStyle(Color.fuelSubtle)
          Text(repsText)
        }
        .font(.fuelMono(.subheadline, weight: 600))
        .foregroundStyle(Color.fuelInk)
        .environment(\.layoutDirection, .leftToRight)
        Text("kg")
          .font(.fuelMono(.caption2, weight: 500))
          .foregroundStyle(Color.fuelSubtle)
        Spacer(minLength: 0)
      }

      if let note = set.note, !note.isEmpty {
        Text(note)
          .font(.fuelBody(.footnote))
          .foregroundStyle(Color.fuelSubtle)
          .padding(.leading, 36)
      }
    }
    .padding(.vertical, 7)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Set \(index)")
    .accessibilityValue("\(weightText) kilograms by \(repsText) reps")
  }
}

#Preview {
  let sessionID = UUID()
  let userID = UUID()
  let benchID = UUID()
  let flyID = UUID()
  return ScrollView {
    SessionExerciseList(exercises: [
      SessionExerciseWithSets(
        exercise: SessionExercise(
          id: benchID, sessionId: sessionID, userId: userID,
          workoutId: "w1", name: "Bench press", position: 0
        ),
        sets: [
          SessionSet(sessionExerciseId: benchID, userId: userID, setNumber: 1, weight: 80, reps: 8),
          SessionSet(sessionExerciseId: benchID, userId: userID, setNumber: 2, weight: 82.5, reps: 6, note: "Felt heavy"),
          SessionSet(sessionExerciseId: benchID, userId: userID, setNumber: 3, weight: nil, reps: 12),
        ]
      ),
      SessionExerciseWithSets(
        exercise: SessionExercise(
          id: flyID, sessionId: sessionID, userId: userID,
          workoutId: nil, name: "Cable fly", position: 1
        ),
        sets: []
      ),
    ])
    .padding()
  }
  .background(Color.fuelBackground)
}
