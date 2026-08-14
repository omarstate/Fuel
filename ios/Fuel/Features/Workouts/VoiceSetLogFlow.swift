import SwiftUI

// Voice set logging — the fastest way to record a set while you're still holding
// the bar. Say "بنش برس تمانين في تمانية، وبعدين خمسة وتمانين في ستة" or
// "bench press 80 for 8, then 85 for 6", and one backend call turns it into
// exercises + sets you confirm with a thumb.
//
// Structurally this is VoiceLogFlow (capture → analyzing → review in one sheet,
// on-device transcription that stays EDITABLE so a denied mic degrades into
// typing), leaner and in the workouts accent. Three deliberate differences:
//
//  • Analyzing is an inline strip, not a full-screen progress view: this is ONE
//    ungrounded call (2–4s), not the meal flow's grounded fan-out.
//  • The sets are written straight to Supabase under RLS, one independent insert
//    each, and the ids come back out through `onLogged` so the host can offer
//    Undo. Catalog learning (aliases + new exercises) is best-effort and can
//    never block logging.
struct VoiceSetLogFlow: View {
  let sessionId: UUID
  /// The rows already in this session — sent as hints so the model can resolve
  /// "same weight" and append to an existing exercise instead of duplicating it.
  let existingExercises: [SessionExerciseWithSets]
  /// The ids of the sets that actually landed. `count` is what the host's banner
  /// says; the ids are what its Undo deletes. One seam rather than two closures.
  var onLogged: ([UUID]) -> Void = { _ in }

  @Environment(\.dismiss) private var dismiss

  @State private var recorder = SpeechRecorder()
  @State private var step: Step = .capture
  @State private var analyzing = false
  @State private var rows: [ExerciseRow] = []
  @State private var error: PresentableError?
  /// The mic starts itself exactly once — re-entering the capture step after a
  /// "Back" from review must not seize the mic again.
  @State private var didAutoStart = false
  /// Capture is a mini modal; only the review step earns the full sheet.
  @State private var detent: PresentationDetent = .height(320)
  @FocusState private var keyboardActive: Bool

  private let repo = WorkoutSessionRepository()

  private enum Step { case capture, review }

  private var trimmedTranscript: String {
    recorder.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Confirm is live WHILE recording — it stops the mic itself. Requiring a stop
  /// first would put a second tap between the user and the only action here.
  private var canAnalyze: Bool {
    !analyzing && trimmedTranscript.count >= 2
  }

  /// The placeholder utterance, in the app's language. The recorder no longer
  /// has a chosen language to ask.
  private var example: String {
    VoiceLanguage.appDefault.example(for: .workout)
  }

  /// Sets carrying a weight or reps — what "Log N sets" counts and writes.
  private var loggableSetCount: Int {
    rows.reduce(0) { $0 + $1.loggableSets.count }
  }

  var body: some View {
    NavigationStack {
      Group {
        switch step {
        case .capture: captureStep
        case .review: reviewForm
        }
      }
      .background(Color.fuelBackground)
      .navigationTitle(step == .capture ? "Log sets by voice" : "Review your sets")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent }
    }
    .presentationDetents([.height(320), .large], selection: $detent)
    .presentationDragIndicator(.visible)
    .interactiveDismissDisabled(analyzing)
    .onChange(of: step) { _, newStep in
      // The review step is a full form; capture is the mini modal it came from.
      withAnimation(.snappy) {
        detent = newStep == .review ? .large : .height(320)
      }
    }
    .task {
      guard !didAutoStart else { return }
      didAutoStart = true
      await recorder.start()
    }
    .onDisappear { recorder.stop() }
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    if step == .capture {
      // Capture has ONE action and it lives on the Confirm button under the
      // wave, so the toolbar keeps only the way out.
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") { dismiss() }
          .disabled(analyzing)
      }
    } else {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          withAnimation(.snappy) { step = .capture }
        } label: {
          Label("Back", systemImage: "chevron.backward")
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        AsyncButton(logLabel, style: .glassProminent, tint: .fuelWorkout, successHaptic: true) {
          try await logAll()
        } onError: { err in
          error = PresentableError(err)
        }
        .disabled(loggableSetCount == 0)
      }
    }
  }

  private var logLabel: LocalizedStringKey {
    loggableSetCount <= 1 ? "Log set" : "Log \(loggableSetCount) sets"
  }

  // MARK: - Capture step

  private var captureStep: some View {
    VStack(spacing: 10) {
      if analyzing {
        analyzingStrip
          .padding(.horizontal, 20)
          .padding(.top, 8)
      }
      if let error {
        ErrorBanner(error: error, onDismiss: { self.error = nil })
          .padding(.horizontal, 20)
          .padding(.top, analyzing ? 0 : 8)
      }
      VoiceCaptureView(
        recorder: recorder,
        accent: .fuelWorkout,
        accentInk: .fuelWorkoutInk,
        example: example,
        isAnalyzing: analyzing,
        canConfirm: canAnalyze,
        onConfirm: confirm
      )
    }
  }

  /// The mini modal's one action: stop listening, then analyze. Errors surface
  /// in the banner above the wave rather than throwing out of the button.
  private func confirm() async {
    await recorder.finish()
    do {
      try await analyze()
    } catch {
      self.error = PresentableError(error)
    }
  }

  // One short call, so the wait is a strip above the wave rather than a screen
  // that throws the transcript away.
  private var analyzingStrip: some View {
    HStack(spacing: 10) {
      ProgressView()
        .controlSize(.small)
        .tint(Color.fuelWorkoutInk)
      Text("Reading what you said…")
        .font(.fuelBody(.subheadline, weight: 500))
        .foregroundStyle(Color.fuelWorkoutInk)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
        .fill(Color.fuelWorkout.opacity(0.12))
    )
  }

  // MARK: - Review step

  private var reviewForm: some View {
    Form {
      ForEach($rows) { $row in
        reviewSection($row)
      }
      errorSection
    }
    .scrollContentBackground(.hidden)
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { keyboardActive = false }
      }
    }
  }

  @ViewBuilder
  private func reviewSection(_ row: Binding<ExerciseRow>) -> some View {
    let value = row.wrappedValue
    Section {
      nameRow(row)

      if value.kind == .custom {
        Toggle("Add to library", isOn: row.addToLibrary)
          .tint(.fuelWorkout)
          .font(.fuelBody(.subheadline))
      }

      ForEach(row.sets) { $set in
        setRow($set, number: value.number(of: set.id), bodyweight: value.bodyweight)
      }
      .onDelete { offsets in
        withAnimation(.snappy) { row.wrappedValue.sets.remove(atOffsets: offsets) }
      }

      Button {
        withAnimation(.snappy) { row.wrappedValue.appendSet() }
      } label: {
        Label("Set", systemImage: "plus")
          .font(.fuelBody(.subheadline, weight: 600))
          .foregroundStyle(Color.fuelWorkoutInk)
          .frame(minHeight: 44)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Add another set")
    } header: {
      HStack(spacing: 6) {
        badges(value)
        Spacer(minLength: 0)
        Button(role: .destructive) {
          withAnimation(.snappy) { rows.removeAll { $0.id == value.id } }
        } label: {
          Image(systemName: "trash")
            .font(.caption.weight(.semibold))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.fuelDestructive)
        .textCase(nil)
        .accessibilityLabel("Remove \(value.trimmedName)")
      }
    } footer: {
      footer(for: value)
    }
  }

  @ViewBuilder
  private func nameRow(_ row: Binding<ExerciseRow>) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      TextField("Exercise name", text: row.name)
        .font(.fuelBody(.body, weight: 500))
        .foregroundStyle(Color.fuelInk)
        .focused($keyboardActive)
        .frame(minHeight: 44)
      // Only when the words differ from the name we're about to log — repeating
      // the name back adds nothing.
      let spoken = row.wrappedValue.spoken
      if !spoken.isEmpty, !VoiceAliases.sameText(spoken, row.wrappedValue.trimmedName) {
        Text("You said “\(spoken)”")
          .font(.fuelBody(.caption))
          .foregroundStyle(Color.fuelSubtle)
      }
    }
  }

  @ViewBuilder
  private func badges(_ row: ExerciseRow) -> some View {
    switch row.kind {
    case .session:
      PillBadge(title: "In this workout", systemImage: "checkmark", tone: .workout)
    case .catalog:
      PillBadge(title: "In your library", systemImage: "books.vertical.fill", tone: .citrus)
    case .custom:
      PillBadge(title: "New exercise", tone: .neutral)
    }
    if row.confidence == .low {
      PillBadge(title: "Check this", systemImage: "exclamationmark.triangle.fill", tone: .gold)
    }
  }

  // One set: its number, a weight and a rep count. Both fields are locale-parsed
  // and clear 44pt; the whole row swipes away.
  private func setRow(_ set: Binding<SetRow>, number: Int, bodyweight: Bool) -> some View {
    HStack(spacing: 10) {
      Text("#\(number)")
        .font(.fuelMono(.caption, weight: 600))
        .foregroundStyle(Color.fuelWorkoutInk)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.fuelWorkout.opacity(0.14)))
        .environment(\.layoutDirection, .leftToRight)

      if set.wrappedValue.showsWeight {
        numberField(text: set.weight, unit: "kg", keyboard: .decimalPad, label: "Weight in kilograms")
      } else {
        // Bodyweight is a real value, not a missing one — but adding a belt is
        // one tap away.
        Text("Bodyweight")
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
        Button("+ add weight") {
          withAnimation(.snappy) { set.wrappedValue.showsWeight = true }
        }
        .font(.fuelBody(.caption, weight: 600))
        .buttonStyle(.plain)
        .foregroundStyle(Color.fuelWorkoutInk)
      }

      Spacer(minLength: 0)
      numberField(text: set.reps, unit: "reps", keyboard: .numberPad, label: "Reps")
    }
    .frame(minHeight: 44)
  }

  private func numberField(
    text: Binding<String>,
    unit: LocalizedStringKey,
    keyboard: UIKeyboardType,
    label: LocalizedStringKey
  ) -> some View {
    HStack(spacing: 4) {
      TextField("0", text: text)
        .keyboardType(keyboard)
        .multilineTextAlignment(.trailing)
        .font(.fuelMono(.body, weight: 600))
        .foregroundStyle(Color.fuelInk)
        .focused($keyboardActive)
        .frame(minWidth: 54, maxWidth: 72)
        .accessibilityLabel(label)
      Text(unit)
        .font(.fuelMono(.caption, weight: 600))
        .foregroundStyle(Color.fuelSubtle)
    }
  }

  @ViewBuilder
  private func footer(for row: ExerciseRow) -> some View {
    let loggable = row.loggableSets
    if !loggable.isEmpty {
      Text(volumeLabel(count: loggable.count, volume: SetMath.volume(sets: loggable)))
        .font(.fuelMono(.caption))
        .foregroundStyle(Color.fuelSubtle)
        .environment(\.layoutDirection, .leftToRight)
    } else {
      Text("Add a weight or some reps to log this one.")
        .font(.fuelBody(.caption))
        .foregroundStyle(Color.fuelSubtle)
    }
  }

  private func volumeLabel(count: Int, volume: Double) -> LocalizedStringKey {
    volume > 0
      ? "\(count) sets · \(DurationFormat.weight(volume)) kg total"
      : "\(count) sets · bodyweight"
  }

  @ViewBuilder
  private var errorSection: some View {
    if let error {
      Section {
        ErrorBanner(error: error, onDismiss: { self.error = nil })
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
      }
    }
  }

  // MARK: - Actions

  private func analyze() async throws {
    recorder.stop()
    keyboardActive = false
    let transcript = trimmedTranscript
    guard transcript.count >= 2 else {
      throw APIError.server(message: String(localized: "Say or type the sets you did first."), status: 400)
    }

    error = nil
    analyzing = true
    defer { analyzing = false }

    // What the recognizers decided was actually spoken. Purely typed input never
    // sets it, so the app's own language is the fallback.
    let lang = recorder.detectedLanguage?.apiLang ?? VoiceLanguage.appDefault.apiLang
    let response = try await FuelAPI.voiceSetLog(
      transcript: transcript,
      lang: lang,
      sessionExercises: existingExercises.map(VoiceSessionExerciseHint.init)
    )
    let parsed = response.exercises.map { exercise in
      ExerciseRow(parsed: exercise, workoutId: workoutId(for: exercise))
    }
    guard !parsed.isEmpty else {
      throw APIError.server(
        message: String(localized: "Couldn't hear an exercise. Try “bench press 80 for 8”."),
        status: 400
      )
    }

    rows = parsed
    withAnimation(.snappy) { step = .review }
  }

  /// A session match usually arrives without the catalog object, so its workout
  /// id comes from the row it matched — that id is what an alias attaches to.
  private func workoutId(for parsed: VoiceParsedExercise) -> String? {
    if let workout = parsed.workout { return workout.id }
    if let id = parsed.sessionExerciseId {
      return existingExercises.first { $0.id == id }?.workoutId
    }
    return nil
  }

  private func logAll() async throws {
    keyboardActive = false
    let usable = rows.filter { !$0.loggableSets.isEmpty }
    guard !usable.isEmpty else {
      throw APIError.server(message: String(localized: "Add a weight or some reps to at least one set."), status: 400)
    }

    // 1. Teach the shared catalog what this utterance revealed — the phrase the
    //    user said, and any new exercise they chose to keep. Entirely
    //    best-effort: catalog learning must NEVER block logging.
    var createdIds: [String: String] = [:]
    let aliasUpdates = usable.compactMap { $0.aliasUpdate() }
    let newWorkouts = usable.compactMap { $0.newWorkoutInput() }
    if !aliasUpdates.isEmpty || !newWorkouts.isEmpty,
       let response = try? await FuelAPI.commitVoiceSetLog(aliasUpdates: aliasUpdates, newWorkouts: newWorkouts) {
      for created in response.workouts {
        createdIds[created.name.lowercased()] = created.workout.id
      }
    }

    // 2. The personal log goes straight to Supabase under RLS, never through the
    //    API. Independent inserts, so one failure keeps the rest.
    let userID = try await repo.userID()
    var setsByExercise = Dictionary(existingExercises.map { ($0.id, $0.sets) }, uniquingKeysWith: { first, _ in first })
    var position = existingExercises.count
    var insertedIds: [UUID] = []

    for row in usable {
      let targetId: UUID
      if let resolved = resolvedExerciseId(for: row) {
        targetId = resolved
      } else {
        let exercise = SessionExercise(
          sessionId: sessionId,
          userId: userID,
          workoutId: row.workoutId ?? createdIds[row.trimmedName.lowercased()],
          name: row.trimmedName,
          position: position
        )
        // Without a parent row its sets have nowhere to land, so this one is
        // skipped rather than retried.
        do {
          try await repo.insertExercise(exercise)
        } catch {
          continue
        }
        position += 1
        setsByExercise[exercise.id] = []
        targetId = exercise.id
      }

      for pending in row.loggableSets {
        let existing = setsByExercise[targetId] ?? []
        let set = SessionSet(
          sessionExerciseId: targetId,
          userId: userID,
          // Numbering continues from what the exercise already has, including
          // the sets this loop just wrote.
          setNumber: SessionStats.nextSetNumber(existing: existing),
          weight: pending.weight,
          reps: pending.reps
        )
        do {
          try await repo.insertSet(set)
          setsByExercise[targetId] = existing + [set]
          insertedIds.append(set.id)
        } catch {
          // Keep going — surfaced below only if nothing at all landed.
        }
      }
    }

    guard !insertedIds.isEmpty else {
      throw APIError.server(message: String(localized: "Couldn't log those sets. Try again."), status: 500)
    }

    onLogged(insertedIds)
    dismiss()
  }

  /// Where a row's sets belong: the row the model matched, else one whose name
  /// says the same thing, else nowhere (the caller inserts a new exercise). The
  /// model's id is verified against the session we were handed — a stale id must
  /// not drop sets into someone else's exercise.
  private func resolvedExerciseId(for row: ExerciseRow) -> UUID? {
    if let id = row.sessionExerciseId, existingExercises.contains(where: { $0.id == id }) {
      return id
    }
    return existingExercises.first { VoiceAliases.sameText($0.name, row.trimmedName) }?.id
  }
}

// MARK: - Review rows

// One editable set. Held as STRINGS so the decimal-pad fields stay controlled
// while they're being typed into — same shape as SetLoggerRow and EstimateRow.
private struct SetRow: Identifiable, Equatable {
  let id = UUID()
  var weight: String
  var reps: String
  /// False for a bodyweight exercise the model heard no weight for: the row
  /// reads "Bodyweight" until the user reveals the field.
  var showsWeight: Bool

  init(weight: String, reps: String, showsWeight: Bool) {
    self.weight = weight
    self.reps = reps
    self.showsWeight = showsWeight
  }

  init(parsed: VoiceParsedSet, bodyweight: Bool) {
    let kg = SetMath.clampWeight(parsed.weight)
    weight = kg.map(DurationFormat.weight) ?? ""
    reps = SetMath.clampReps(parsed.reps).map(String.init) ?? ""
    showsWeight = kg != nil || !bodyweight
  }

  // Locale-aware parsing (Arabic separators and digits) — never Double(string).
  // A hidden weight field is bodyweight no matter what text it holds.
  var parsedWeight: Double? {
    showsWeight ? SetMath.clampWeight(NumberParsing.double(weight)) : nil
  }

  var parsedReps: Int? { SetMath.clampReps(NumberParsing.int(reps)) }
}

// One editable exercise: what the model heard, what it matched, and the sets
// under it.
private struct ExerciseRow: Identifiable, Equatable {
  let id = UUID()
  let kind: VoiceExerciseKind
  let spoken: String
  var name: String
  let bodyweight: Bool
  let confidence: VoiceConfidence?
  /// The session row to append to, when the model matched one.
  let sessionExerciseId: UUID?
  /// The catalog workout behind this row, if any — what an alias attaches to.
  let workoutId: String?
  /// Custom rows only, default OFF: saving a one-off to the shared catalog is a
  /// choice, not a side effect of logging.
  var addToLibrary = false
  var sets: [SetRow]

  init(parsed: VoiceParsedExercise, workoutId: String?) {
    kind = parsed.kind
    spoken = parsed.spoken
    name = parsed.name.isEmpty ? parsed.spoken : parsed.name
    bodyweight = parsed.bodyweight
    confidence = parsed.confidence
    sessionExerciseId = parsed.sessionExerciseId
    self.workoutId = workoutId
    let mapped = parsed.sets.map { SetRow(parsed: $0, bodyweight: parsed.bodyweight) }
    // An exercise with no sets heard still gets one blank row — the user came
    // here to log something.
    sets = mapped.isEmpty ? [SetRow(weight: "", reps: "", showsWeight: !parsed.bodyweight)] : mapped
  }

  var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

  func number(of setId: UUID) -> Int {
    (sets.firstIndex { $0.id == setId } ?? 0) + 1
  }

  /// The sets worth writing: a set needs a weight OR reps to mean anything.
  var loggableSets: [(weight: Double?, reps: Int?)] {
    sets.compactMap { set in
      let weight = set.parsedWeight
      let reps = set.parsedReps
      guard weight != nil || reps != nil else { return nil }
      return (weight, reps)
    }
  }

  /// "+ Set" duplicates the last one — the common case is another set at the
  /// same weight.
  mutating func appendSet() {
    guard let last = sets.last else {
      sets.append(SetRow(weight: "", reps: "", showsWeight: !bodyweight))
      return
    }
    sets.append(SetRow(weight: last.weight, reps: last.reps, showsWeight: last.showsWeight))
  }

  /// The phrase to teach the catalog workout this row matched. Custom rows have
  /// no workout to teach yet — their alias rides along with the new workout.
  func aliasUpdate() -> VoiceWorkoutAliasUpdate? {
    guard kind != .custom, let workoutId, !workoutId.isEmpty else { return nil }
    let aliases = WorkoutVoiceAliases.deriveAliases(spoken: spoken, name: trimmedName)
    guard !aliases.isEmpty else { return nil }
    return VoiceWorkoutAliasUpdate(workoutId: workoutId, aliases: aliases)
  }

  /// A new catalog exercise, only when the user opted in.
  func newWorkoutInput() -> VoiceNewWorkoutInput? {
    guard kind == .custom, addToLibrary, !trimmedName.isEmpty else { return nil }
    return VoiceNewWorkoutInput(
      name: trimmedName,
      primaryMuscle: nil,
      equipment: nil,
      aliases: WorkoutVoiceAliases.deriveAliases(spoken: spoken, name: trimmedName)
    )
  }
}

#Preview {
  let sessionID = UUID()
  let userID = UUID()
  let benchID = UUID()

  return VoiceSetLogFlow(
    sessionId: sessionID,
    existingExercises: [
      SessionExerciseWithSets(
        exercise: SessionExercise(
          id: benchID, sessionId: sessionID, userId: userID,
          workoutId: "w1", name: "Barbell bench press", position: 0
        ),
        sets: [
          SessionSet(sessionExerciseId: benchID, userId: userID, setNumber: 1, weight: 80, reps: 8),
        ]
      )
    ]
  )
}
