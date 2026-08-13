import SwiftUI

// One exercise inside a live session: what you've already done (the set pills),
// and the one control that matters (the logger). Port of
// workouts/session/active-exercise-card.tsx.
//
// This is an opaque `.fuelCard()` — content, never glass. Only the rest bar
// floating over it gets the glass treatment.
struct ActiveExerciseCard: View {
  let exercise: SessionExerciseWithSets
  /// weight, reps → whether the set landed. The parent starts the rest timer
  /// and checks milestones off the result.
  let onLogSet: (Double?, Int?) async -> Bool
  let onUpdateSet: (UUID, Double?, Int?, String?) async -> Bool
  let onDeleteSet: (UUID) async -> Bool
  let onDeleteExercise: () async -> Bool

  @State private var selectedSetID: UUID?
  @State private var confirmingDelete = false
  /// Bumped when a removal is actually confirmed, for the impact haptic.
  @State private var deleteTick = 0

  private var selected: (set: SessionSet, index: Int)? {
    guard let selectedSetID,
          let index = exercise.sets.firstIndex(where: { $0.id == selectedSetID })
    else { return nil }
    return (exercise.sets[index], index + 1)
  }

  private var lastSet: SessionSet? { exercise.sets.last }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header

      if !exercise.sets.isEmpty {
        FlowLayout(spacing: 6, lineSpacing: 6) {
          ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
            SetPill(
              set: set,
              index: index + 1,
              isSelected: set.id == selectedSetID,
              onTap: {
                withAnimation(.snappy) {
                  selectedSetID = selectedSetID == set.id ? nil : set.id
                }
              }
            )
          }
        }
      }

      if let selected {
        SetEditorRow(
          set: selected.set,
          index: selected.index,
          onSave: { weight, reps, note in
            await onUpdateSet(selected.set.id, weight, reps, note)
          },
          onDelete: {
            let dropped = await onDeleteSet(selected.set.id)
            if dropped { withAnimation(.snappy) { selectedSetID = nil } }
            return dropped
          },
          onClose: { withAnimation(.snappy) { selectedSetID = nil } }
        )
        // A new selection rebuilds the editor, so its fields reseed from the
        // set that was actually tapped.
        .id(selected.set.id)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }

      Divider()
        .overlay(Color.fuelInk.opacity(0.08))

      SetLoggerRow(
        defaultWeight: lastSet?.weight,
        defaultReps: lastSet?.reps,
        onLog: onLogSet
      )
      // Keyed by exercise so the prefill belongs to THIS exercise's last set and
      // doesn't carry over when the list re-orders.
      .id(exercise.id)
    }
    .padding(16)
    .fuelCard()
    .confirmationDialog(
      "Remove this exercise?",
      isPresented: $confirmingDelete,
      titleVisibility: .visible
    ) {
      Button("Remove \(exercise.name)", role: .destructive) {
        deleteTick += 1
        Task { _ = await onDeleteExercise() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("\(exercise.name) and its \(exercise.sets.count) logged sets will be removed from this session.")
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: deleteTick)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(exercise.name)
        .font(.fuelBody(.body, weight: 600))
        .foregroundStyle(Color.fuelInk)

      if exercise.workoutId == nil {
        PillBadge(title: "Custom", tone: .neutral)
      }
      if !exercise.sets.isEmpty {
        PillBadge(title: setCountLabel, tone: .gold)
      }

      Spacer(minLength: 0)

      Button {
        confirmingDelete = true
      } label: {
        Image(systemName: "trash")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Color.fuelDestructive)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Remove \(exercise.name)")
    }
  }

  private var setCountLabel: LocalizedStringKey {
    exercise.sets.count == 1 ? "1 set" : "\(exercise.sets.count) sets"
  }
}

#Preview {
  let sessionID = UUID()
  let userID = UUID()
  let exerciseID = UUID()
  let exercise = SessionExerciseWithSets(
    exercise: SessionExercise(
      id: exerciseID, sessionId: sessionID, userId: userID,
      workoutId: nil, name: "Incline dumbbell press", position: 0
    ),
    sets: [
      SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 1, weight: 30, reps: 12),
      SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 2, weight: 32.5, reps: 10, note: "Slow eccentric"),
      SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 3, weight: 32.5, reps: 8),
    ]
  )
  return ScrollView {
    ActiveExerciseCard(
      exercise: exercise,
      onLogSet: { _, _ in true },
      onUpdateSet: { _, _, _, _ in true },
      onDeleteSet: { _ in true },
      onDeleteExercise: { true }
    )
    .padding()
  }
  .background(Color.fuelBackground)
}
