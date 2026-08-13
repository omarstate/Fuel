import SwiftUI

// One-tap set logging — the single most-used control in the whole workouts
// flow, so it is built for a sweaty thumb: both steppers and the log button
// clear 44pt, the fields are prefilled from the previous set, and a repeat set
// is one press. Port of workouts/session/set-logger.tsx.
//
// The web seeds its inputs once and leaves them alone afterwards (the component
// is keyed by exercise id); this does the same by initializing @State from the
// defaults, so what you typed survives logging and only a different exercise
// resets it.
struct SetLoggerRow: View {
  let defaultWeight: Double?
  let defaultReps: Int?
  /// Returns whether the set actually landed, so the burst/haptic only fire on
  /// a real write and the parent can start the rest timer.
  let onLog: (Double?, Int?) async -> Bool

  @State private var weight: String
  @State private var reps: String
  /// Bumped per successful log, purely to re-fire the icon's bounce.
  @State private var logTick = 0
  /// Bumped per stepper tap, for the light impact haptic.
  @State private var stepTick = 0
  @FocusState private var focus: Field?

  private enum Field: Hashable {
    case weight
    case reps
  }

  private static let weightStep = 2.5

  init(defaultWeight: Double?, defaultReps: Int?, onLog: @escaping (Double?, Int?) async -> Bool) {
    self.defaultWeight = defaultWeight
    self.defaultReps = defaultReps
    self.onLog = onLog
    _weight = State(initialValue: defaultWeight.map(DurationFormat.weight) ?? "")
    _reps = State(initialValue: defaultReps.map(String.init) ?? "")
  }

  // Locale-aware parsing (Arabic separators/digits) — never Double(string).
  private var weightValue: Double? { NumberParsing.double(weight) }
  private var repsValue: Int? { NumberParsing.int(reps) }

  private var canLog: Bool {
    (repsValue ?? 0) > 0 || (weightValue ?? 0) > 0
  }

  var body: some View {
    VStack(spacing: 10) {
      HStack(alignment: .bottom, spacing: 10) {
        stepper(
          label: "Weight",
          unit: "kg · ±2.5",
          placeholder: "BW",
          text: $weight,
          field: .weight,
          keyboard: .decimalPad,
          decreaseLabel: "Less weight",
          increaseLabel: "More weight",
          onStep: stepWeight
        )
        stepper(
          label: "Reps",
          unit: "±1",
          placeholder: "0",
          text: $reps,
          field: .reps,
          keyboard: .numberPad,
          decreaseLabel: "Fewer reps",
          increaseLabel: "More reps",
          onStep: stepReps
        )
      }
      .sensoryFeedback(.impact(weight: .light), trigger: stepTick)

      AsyncButton(
        style: .glassProminent,
        tint: .fuelWorkout,
        successHaptic: true,
        action: log,
        onError: { _ in }
      ) {
        HStack(spacing: 8) {
          Image(systemName: "bolt.fill")
            .font(.system(size: 15, weight: .bold))
            .symbolEffect(.bounce, value: logTick)
          Text(logLabel)
            .font(.fuelHeading(.headline))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
      }
      .disabled(!canLog)
    }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        if focus == .weight {
          Button("Next") { focus = .reps }
        }
        Spacer()
        Button("Done") { focus = nil }
      }
    }
  }

  // MARK: - Label

  // "Log 80 kg × 8" when a weight is set, "Log 8 reps" for a bodyweight set.
  private var logLabel: LocalizedStringKey {
    if let weightValue, weightValue > 0 {
      let kg = DurationFormat.weight(weightValue)
      if let repsValue, repsValue > 0 {
        return "Log \(kg) kg × \(repsValue)"
      }
      return "Log \(kg) kg"
    }
    if let repsValue, repsValue > 0 {
      return "Log \(repsValue) reps"
    }
    return "Log set"
  }

  // MARK: - Stepper

  private func stepper(
    label: LocalizedStringKey,
    unit: LocalizedStringKey,
    placeholder: LocalizedStringKey,
    text: Binding<String>,
    field: Field,
    keyboard: UIKeyboardType,
    decreaseLabel: LocalizedStringKey,
    increaseLabel: LocalizedStringKey,
    onStep: @escaping (Int) -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 5) {
        Text(label).fuelEyebrow()
        Text(unit)
          .font(.fuelMono(.caption2, weight: 500))
          .foregroundStyle(Color.fuelSubtle.opacity(0.8))
      }
      HStack(spacing: 0) {
        stepButton("minus", label: decreaseLabel) { onStep(-1) }
        TextField(placeholder, text: text)
          .keyboardType(keyboard)
          .multilineTextAlignment(.center)
          .font(.fuelMono(.title3, weight: 600))
          .foregroundStyle(Color.fuelInk)
          .focused($focus, equals: field)
          .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
        stepButton("plus", label: increaseLabel) { onStep(1) }
      }
      .background(Color.fuelBackground, in: RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
          .strokeBorder(Color.fuelInk.opacity(0.08), lineWidth: 1)
      )
    }
    .frame(maxWidth: .infinity)
  }

  private func stepButton(_ systemName: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(.snappy) { action() }
      stepTick += 1
    } label: {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(Color.fuelWorkoutInk)
        .frame(width: 44, height: 44)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  // MARK: - Actions

  // Clearing to zero empties the field, so "0" never gets logged as a weight —
  // an empty weight means bodyweight, which is a different thing (web parity).
  private func stepWeight(_ direction: Int) {
    let next = max(0, (weightValue ?? 0) + Double(direction) * Self.weightStep)
    weight = next == 0 ? "" : DurationFormat.weight(next)
  }

  private func stepReps(_ direction: Int) {
    let next = max(0, (repsValue ?? 0) + direction)
    reps = next == 0 ? "" : String(next)
  }

  private func log() async {
    guard canLog else { return }
    focus = nil
    let landed = await onLog(weightValue, repsValue)
    if landed { logTick += 1 }
  }
}

#Preview {
  VStack(spacing: 20) {
    SetLoggerRow(defaultWeight: 80, defaultReps: 8) { _, _ in true }
    SetLoggerRow(defaultWeight: nil, defaultReps: 12) { _, _ in true }
    SetLoggerRow(defaultWeight: nil, defaultReps: nil) { _, _ in true }
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
