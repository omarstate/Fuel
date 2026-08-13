import SwiftUI

// A logged set, as a tappable capsule: "#2  80 × 8". Port of the SetPill in
// workouts/session/active-exercise-card.tsx. A set with no weight is bodyweight,
// which reads "— × 8" rather than "0 × 8" — zero would be a lie about the load.
// The dot on the right means the set carries a note.
struct SetPill: View {
  let set: SessionSet
  /// 1-based position among the exercise's sets, as shown to the user. This is
  /// the display index, NOT `set.setNumber` — numbering skips after a delete.
  let index: Int
  let isSelected: Bool
  let onTap: () -> Void

  private var weightText: String {
    guard let weight = set.weight else { return "—" }
    return DurationFormat.weight(weight)
  }

  private var repsText: String {
    guard let reps = set.reps else { return "—" }
    return String(reps)
  }

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 6) {
        Text("#\(index)")
          .font(.fuelMono(.caption2, weight: 500))
          .foregroundStyle(Color.fuelSubtle)
        HStack(spacing: 3) {
          Text(weightText)
          Text("×").foregroundStyle(Color.fuelSubtle)
          Text(repsText)
        }
        .font(.fuelMono(.subheadline, weight: 600))
        .foregroundStyle(Color.fuelInk)
        if set.note?.isEmpty == false {
          Circle()
            .fill(Color.fuelWorkoutInk)
            .frame(width: 5, height: 5)
        }
      }
      .environment(\.layoutDirection, .leftToRight)
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .background(
        Capsule().fill(isSelected ? Color.fuelWorkout.opacity(0.18) : Color.fuelBackground)
      )
      .overlay(
        Capsule().strokeBorder(
          isSelected ? Color.fuelWorkoutInk.opacity(0.45) : Color.fuelInk.opacity(0.08),
          lineWidth: 1
        )
      )
      .contentShape(.capsule)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Set \(index)")
    .accessibilityValue("\(weightText) kilograms by \(repsText) reps")
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
  }
}

// The inline editor a selected pill reveals underneath the row. Chosen over
// expanding the pill in place because the pills live in a wrapping flow layout —
// growing one mid-row reshuffles every pill after it, which is disorienting when
// the thing you tapped jumps somewhere else.
//
// Edits are committed together on "Done" rather than per-field-blur (the web's
// model): one write instead of three, and PostgREST's full-field patch means a
// cleared field genuinely clears the column.
struct SetEditorRow: View {
  let set: SessionSet
  let index: Int
  /// weight, reps, note → whether the update landed.
  let onSave: (Double?, Int?, String?) async -> Bool
  let onDelete: () async -> Bool
  let onClose: () -> Void

  @State private var weight: String
  @State private var reps: String
  @State private var note: String
  @FocusState private var focus: Field?

  private enum Field: Hashable {
    case weight
    case reps
    case note
  }

  init(
    set: SessionSet,
    index: Int,
    onSave: @escaping (Double?, Int?, String?) async -> Bool,
    onDelete: @escaping () async -> Bool,
    onClose: @escaping () -> Void
  ) {
    self.set = set
    self.index = index
    self.onSave = onSave
    self.onDelete = onDelete
    self.onClose = onClose
    _weight = State(initialValue: set.weight.map(DurationFormat.weight) ?? "")
    _reps = State(initialValue: set.reps.map(String.init) ?? "")
    _note = State(initialValue: set.note ?? "")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Set #\(index)")
        .fuelEyebrow()

      HStack(spacing: 8) {
        field("kg", text: $weight, focus: .weight, keyboard: .decimalPad, width: 72)
        field("reps", text: $reps, focus: .reps, keyboard: .numberPad, width: 72)
        field("Note", text: $note, focus: .note, keyboard: .default, width: nil)
      }

      HStack(spacing: 10) {
        AsyncButton(
          role: .destructive,
          style: .glass,
          tint: .fuelDestructive,
          action: delete,
          onError: { _ in }
        ) {
          Label("Delete set", systemImage: "trash")
            .font(.fuelBody(.subheadline, weight: 600))
        }

        Spacer(minLength: 0)

        AsyncButton(
          style: .glassProminent,
          tint: .fuelWorkout,
          successHaptic: true,
          action: save,
          onError: { _ in }
        ) {
          Label("Done", systemImage: "checkmark")
            .font(.fuelBody(.subheadline, weight: 600))
        }
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
        .fill(Color.fuelWorkout.opacity(0.10))
    )
    .overlay(
      RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
        .strokeBorder(Color.fuelWorkoutInk.opacity(0.25), lineWidth: 1)
    )
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focus = nil }
      }
    }
  }

  private func field(
    _ placeholder: LocalizedStringKey,
    text: Binding<String>,
    focus field: Field,
    keyboard: UIKeyboardType,
    width: CGFloat?
  ) -> some View {
    TextField(placeholder, text: text)
      .keyboardType(keyboard)
      .font(keyboard == .default ? .fuelBody(.subheadline) : .fuelMono(.subheadline, weight: 600))
      .foregroundStyle(Color.fuelInk)
      .focused($focus, equals: field)
      // A nil width means "take the rest of the row" (the note field).
      .frame(minWidth: width, maxWidth: width ?? .infinity, minHeight: 44)
      .padding(.horizontal, 10)
      .background(Color.fuelSurface, in: RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
          .strokeBorder(Color.fuelInk.opacity(0.08), lineWidth: 1)
      )
  }

  private func save() async {
    focus = nil
    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let landed = await onSave(
      NumberParsing.double(weight),
      NumberParsing.int(reps),
      trimmedNote.isEmpty ? nil : trimmedNote
    )
    if landed { onClose() }
  }

  private func delete() async {
    focus = nil
    if await onDelete() { onClose() }
  }
}

#Preview {
  let exerciseID = UUID()
  let userID = UUID()
  let sets = [
    SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 1, weight: 80, reps: 8),
    SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 2, weight: 82.5, reps: 6, note: "Felt heavy"),
    SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 3, weight: nil, reps: 20),
  ]
  return VStack(alignment: .leading, spacing: 12) {
    FlowLayout(spacing: 6, lineSpacing: 6) {
      ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
        SetPill(set: set, index: index + 1, isSelected: index == 1, onTap: {})
      }
    }
    SetEditorRow(set: sets[1], index: 2, onSave: { _, _, _ in true }, onDelete: { true }, onClose: {})
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
