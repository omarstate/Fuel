import SwiftUI
import UIKit

// The live workout session — the screen you actually stand in front of a rack
// holding. Port of workouts/session/session-active.tsx.
//
// Full-screen by design (hosts present it with `.fullScreenCover`): a session in
// progress is a mode, not a page, so it carries its own plain top bar instead of
// a NavigationStack — there is nowhere to navigate back TO while it runs, only
// "minimize" and "end". Chrome-wise it follows the same recipe as VoiceLogFlow's
// full-screen surfaces: cream canvas, opaque content cards, and glass reserved
// for the one floating element (the rest bar).
struct ActiveSessionView: View {
  let sessionId: UUID
  /// Fires with the session id after a successful end, so the host can dismiss
  /// and route on to the summary.
  var onEnded: (UUID) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var model: ActiveSessionViewModel
  @State private var rest = RestTimer()
  @State private var confirmingEnd = false
  /// Catalog exercises for this session's category, fetched once. A failure
  /// leaves it empty — suggestions are a convenience, never a blocker.
  @State private var catalog: [Workout] = []
  /// The user's last completed sessions, behind the inline suggestions and the
  /// picker's recents. Soft-fails to empty like the catalog.
  @State private var recentSessions: [SessionWithExercises] = []
  @State private var showPicker = false
  @State private var milestone: String?
  @State private var milestoneTick = 0
  @State private var endedTick = 0
  @State private var showVoiceLog = false
  /// The sets the last voice log wrote, so its banner can offer a real Undo.
  @State private var undoableSetIds: [UUID] = []
  @State private var undoTick = 0

  init(sessionId: UUID, onEnded: @escaping (UUID) -> Void = { _ in }) {
    self.sessionId = sessionId
    self.onEnded = onEnded
    _model = State(initialValue: ActiveSessionViewModel(sessionId: sessionId))
  }

  /// Preview/host seam for a model that already holds its session.
  init(model: ActiveSessionViewModel, onEnded: @escaping (UUID) -> Void = { _ in }) {
    self.sessionId = model.sessionId
    self.onEnded = onEnded
    _model = State(initialValue: model)
  }

  var body: some View {
    VStack(spacing: 0) {
      topBar
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          if let error = model.error {
            ErrorBanner(
              error: error,
              onRetry: { Task { await model.load() } },
              onDismiss: { model.error = nil }
            )
          }
          content
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        // Cards slide in/out as exercises are added and removed; the stats above
        // them ride the same spring.
        .animation(.snappy, value: model.exercises.map(\.id))
      }
      .scrollDismissesKeyboard(.interactively)
      .scrollEdgeEffectStyle(.soft, for: .top)
    }
    .background(Color.fuelBackground.ignoresSafeArea())
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 8) {
        if !undoableSetIds.isEmpty {
          undoBanner(count: undoableSetIds.count)
        }
        if let milestone {
          milestoneBanner(milestone)
        }
        RestTimerBar(timer: rest)
      }
      .animation(.snappy, value: milestone)
      .animation(.snappy, value: undoableSetIds)
    }
    .task {
      // Only on a cold model — re-entering must not clobber local state with a
      // fresh fetch (and previews come pre-seeded).
      if model.session == nil { await model.load() }
      await loadCatalog()
      await loadRecentSessions()
    }
    // Render cold-starts run 30–60s. The mic must never be the thing waiting on
    // one, so the server is woken the moment this screen appears.
    .task { await FuelAPI.warmUp() }
    .sheet(isPresented: $showVoiceLog) {
      VoiceSetLogFlow(
        sessionId: sessionId,
        existingExercises: model.exercises,
        onLogged: { ids in
          Task { await voiceSetsLanded(ids) }
        }
      )
    }
    .sheet(isPresented: $showPicker) {
      ExercisePickerSheet(
        recents: ExercisePicker.recents(from: recentSessions),
        existingNames: model.existingNames,
        initialCategorySlug: model.categorySlug,
        fallbackCatalog: catalog,
        onPick: { name, workoutId in
          showPicker = false
          Task { await add(name: name, workoutId: workoutId) }
        }
      )
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
    .task(id: undoTick) {
      guard !undoableSetIds.isEmpty else { return }
      try? await Task.sleep(for: .seconds(6))
      guard !Task.isCancelled else { return }
      withAnimation(.snappy) { undoableSetIds = [] }
    }
    // Gym phones must not sleep mid-set. Guarded on both edges so leaving the
    // screen by any route (minimize, end, host dismissal) always restores it.
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    .task(id: milestoneTick) {
      guard milestone != nil else { return }
      try? await Task.sleep(for: .seconds(2.5))
      guard !Task.isCancelled else { return }
      withAnimation(.snappy) { milestone = nil }
    }
    .sensoryFeedback(.success, trigger: endedTick)
    .confirmationDialog("End this session?", isPresented: $confirmingEnd, titleVisibility: .visible) {
      Button("End session", role: .destructive) {
        Task { await endSession() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This marks the session complete and takes you to the summary. You can't resume it afterward.")
    }
  }

  // MARK: - Top bar

  // Plain, not glass: it is chrome sitting ON the canvas, and DESIGN.md reserves
  // glass for things that float above content.
  private var topBar: some View {
    HStack(alignment: .center, spacing: 8) {
      Button {
        dismiss()
      } label: {
        Label("Minimize", systemImage: "chevron.down")
          .font(.fuelBody(.footnote, weight: 600))
          .foregroundStyle(Color.fuelSubtle)
          .frame(height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)

      Spacer(minLength: 0)

      VStack(spacing: 2) {
        Text(model.categoryName ?? String(localized: "Session"))
          .fuelEyebrow(color: .fuelWorkoutInk)
        HStack(spacing: 6) {
          LivePulseDot()
          Text("In progress")
            .font(.fuelBody(.subheadline, weight: 600))
            .foregroundStyle(Color.fuelInk)
        }
      }
      .layoutPriority(1)

      Spacer(minLength: 0)

      Button {
        showVoiceLog = true
      } label: {
        Image(systemName: "waveform")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color.fuelWorkoutInk)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .disabled(model.session == nil)
      .accessibilityLabel("Log sets by voice")

      Button(role: .destructive) {
        confirmingEnd = true
      } label: {
        Text("End session")
          .font(.fuelBody(.footnote, weight: 600))
          .foregroundStyle(Color.fuelWorkoutInk)
          .frame(height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .disabled(model.session == nil)
    }
    .padding(.horizontal, 16)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.fuelInk.opacity(0.06))
        .frame(height: 1)
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    if let session = model.session {
      elapsedBlock(startedAt: session.startedAt)
      SessionStatsRow(
        exercises: model.totals.exercises,
        sets: model.totals.sets,
        volumeKg: model.totals.volumeKg
      )

      if model.exercises.isEmpty {
        emptyState
      } else {
        ForEach(model.exercises) { exercise in
          ActiveExerciseCard(
            exercise: exercise,
            onLogSet: { weight, reps in
              await logSet(exerciseId: exercise.id, weight: weight, reps: reps)
            },
            onUpdateSet: { setId, weight, reps, note in
              await model.updateSet(id: setId, weight: weight, reps: reps, note: note)
            },
            onDeleteSet: { setId in await model.deleteSet(id: setId) },
            onDeleteExercise: { await model.deleteExercise(exercise) }
          )
        }
      }

      addExerciseCard
    } else if model.error == nil {
      skeleton
    }
  }

  private func elapsedBlock(startedAt: Date) -> some View {
    VStack(spacing: 2) {
      Text("Elapsed").fuelEyebrow()
      SessionTimerView(startedAt: startedAt)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 4)
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("Log your first exercise", systemImage: "dumbbell.fill")
        .font(.fuelHeading(.headline))
    } description: {
      Text("Pick a suggestion below or browse all exercises.")
        .font(.fuelBody(.subheadline))
    } actions: {
      Button("Add an exercise") { showPicker = true }
        .buttonStyle(.glass)
        .tint(.fuelWorkout)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
  }

  // First load only — the instant-render rule means a refresh never falls back
  // to this.
  private var skeleton: some View {
    VStack(alignment: .leading, spacing: 14) {
      SessionStatsRow(exercises: 3, sets: 12, volumeKg: 4_200)
      ForEach(0..<2, id: \.self) { _ in
        VStack(alignment: .leading, spacing: 12) {
          Text("Bench press")
            .font(.fuelBody(.body, weight: 600))
          Text("80 × 8   82.5 × 6")
            .font(.fuelMono(.subheadline, weight: 600))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .fuelCard()
      }
    }
    .redacted(reason: .placeholder)
    .accessibilityHidden(true)
  }

  // MARK: - Add exercise

  /// At most six chips: what you did last time in this category first, then the
  /// catalog. The old card dumped thirty identical capsules into the scroll and
  /// asked you to read them; six you recognise is a faster tap than any list.
  private var suggestions: [ExercisePicker.Suggestion] {
    ExercisePicker.suggestions(
      sessions: recentSessions,
      categorySlug: model.categorySlug,
      catalog: catalog,
      existingNames: model.existingNames
    )
  }

  private var addExerciseCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Add exercise").fuelEyebrow()

      if !suggestions.isEmpty {
        FlowLayout(spacing: 8, lineSpacing: 8) {
          ForEach(suggestions) { suggestion in
            Button {
              Task { await add(name: suggestion.name, workoutId: suggestion.workoutId) }
            } label: {
              Text(suggestion.name)
                .font(.fuelBody(.subheadline))
                .foregroundStyle(Color.fuelInk)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Capsule().fill(Color.fuelSurface))
                .overlay(Capsule().strokeBorder(Color.fuelInk.opacity(0.08), lineWidth: 1))
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
          }
        }
      }

      HStack(spacing: 8) {
        Button {
          showPicker = true
        } label: {
          Label("Browse all exercises", systemImage: "list.magnifyingglass")
            .font(.fuelBody(.subheadline, weight: 600))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
        .tint(.fuelWorkout)

        // Saying it is faster than tapping it, and this is where the user is
        // already looking when they go to add something.
        Button {
          showVoiceLog = true
        } label: {
          Image(systemName: "mic.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.fuelWorkoutInk)
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(model.session == nil)
        .accessibilityLabel("Log sets by voice")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: FuelRadius.card, style: .continuous)
        .fill(Color.fuelSurface.opacity(0.5))
    )
    .overlay(
      RoundedRectangle(cornerRadius: FuelRadius.card, style: .continuous)
        .strokeBorder(Color.fuelInk.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [5]))
    )
  }

  // MARK: - Milestones

  // A transient capsule above the rest bar — the native equivalent of the web's
  // sonner toast, without stealing focus or covering the logger.
  private func milestoneBanner(_ text: String) -> some View {
    Text(text)
      .font(.fuelBody(.subheadline, weight: 600))
      .foregroundStyle(Color.fuelWorkoutInk)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(Capsule().fill(Color.fuelWorkout.opacity(0.12)))
      .padding(.horizontal, 16)
      .transition(.opacity.combined(with: .move(edge: .bottom)))
      .accessibilityAddTraits(.isStaticText)
  }

  // A voice log writes several sets at once, so the way back is a real Undo on
  // the banner rather than deleting them one pill at a time.
  private func undoBanner(count: Int) -> some View {
    HStack(spacing: 12) {
      Text(count == 1 ? "Logged 1 set" : "Logged \(count) sets")
        .font(.fuelBody(.subheadline, weight: 600))
        .foregroundStyle(Color.fuelWorkoutInk)
      Button("Undo") {
        Task { await undoVoiceSets() }
      }
      .font(.fuelBody(.subheadline, weight: 700))
      .buttonStyle(.plain)
      .foregroundStyle(Color.fuelWorkoutInk)
      .frame(minHeight: 44)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
    .background(Capsule().fill(Color.fuelWorkout.opacity(0.16)))
    .padding(.horizontal, 16)
    .transition(.opacity.combined(with: .move(edge: .bottom)))
  }

  // Every 5th set gets a line, rotating through four of them (web SET_MILESTONES).
  private static func setMilestone(_ count: Int) -> String {
    switch (count / 5 - 1) % 4 {
    case 0: return String(localized: "\(count) sets down — momentum is real 💪")
    case 1: return String(localized: "\(count) sets. You're a machine ⚙️")
    case 2: return String(localized: "\(count) sets in — most people quit before this 🔥")
    default: return String(localized: "\(count) sets. Certified workhorse 🏋️")
    }
  }

  private func show(milestone text: String) {
    withAnimation(.snappy) { milestone = text }
    milestoneTick += 1
  }

  // MARK: - Actions

  private func loadCatalog() async {
    guard catalog.isEmpty, let slug = model.categorySlug else { return }
    // Soft-fail: no chips is a smaller problem than an error banner over a
    // session the user is mid-set in.
    guard let result = try? await FuelAPI.workouts(category: slug, search: "", limit: 30, offset: 0) else { return }
    withAnimation(.snappy) { catalog = result.items }
  }

  // Same soft-fail contract as the catalog: no history just means the
  // suggestions fall back to the catalog order.
  private func loadRecentSessions() async {
    guard recentSessions.isEmpty else { return }
    guard let sessions = try? await WorkoutSessionRepository().recentSessions() else { return }
    withAnimation(.snappy) { recentSessions = sessions }
  }

  @discardableResult
  private func add(name: String, workoutId: String?) async -> Bool {
    await model.addExercise(name: name, workoutId: workoutId)
  }

  // Log, then start the rest countdown and celebrate — session best takes
  // precedence over the set-count milestone, exactly like the web.
  private func logSet(exerciseId: UUID, weight: Double?, reps: Int?) async -> Bool {
    let previousBest = model.bestWeight ?? 0
    let previousSets = model.totalSetCount

    guard await model.logSet(exerciseId: exerciseId, weight: weight, reps: reps) else { return false }
    rest.start()

    if let weight, weight > previousBest, previousBest > 0 {
      show(milestone: String(localized: "New session best — \(DurationFormat.weight(weight)) kg 🏆"))
    } else {
      let nextSets = previousSets + 1
      if SessionStats.isMilestone(totalSetCount: nextSets) {
        show(milestone: Self.setMilestone(nextSets))
      }
    }
    return true
  }

  // A voice log writes exercises AND sets behind the view model's back (it owns
  // one optimistic mutation at a time, not a batch), so the simplest correct
  // reconciliation is a fresh nested reload.
  private func voiceSetsLanded(_ ids: [UUID]) async {
    await model.load()
    guard !ids.isEmpty else { return }
    withAnimation(.snappy) { undoableSetIds = ids }
    undoTick += 1
  }

  private func undoVoiceSets() async {
    let ids = undoableSetIds
    withAnimation(.snappy) { undoableSetIds = [] }
    // Each delete is optimistic in the view model and rolls itself back on
    // failure, so a partial undo still leaves the screen truthful.
    for id in ids {
      await model.deleteSet(id: id)
    }
  }

  private func endSession() async {
    guard await model.endSession() else { return }
    endedTick += 1
    // Nothing may buzz after the user has walked away.
    rest.skip()
    onEnded(sessionId)
    dismiss()
  }
}

// The "this is live" indicator beside "In progress" — a slow accent pulse,
// matching the web's animated dot.
private struct LivePulseDot: View {
  @State private var dim = false

  var body: some View {
    Circle()
      .fill(Color.fuelWorkout)
      .frame(width: 9, height: 9)
      .opacity(dim ? 0.25 : 1)
      .scaleEffect(dim ? 0.8 : 1)
      .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: dim)
      .onAppear { dim = true }
      .accessibilityHidden(true)
  }
}

#Preview {
  let userID = UUID()
  let sessionID = UUID()
  let benchID = UUID()
  let rowID = UUID()

  let session = SessionWithExercises(
    session: WorkoutSession(
      id: sessionID,
      userId: userID,
      categoryName: "Push day",
      categorySlug: "push",
      startedAt: Date().addingTimeInterval(-2_215)
    ),
    exercises: [
      SessionExerciseWithSets(
        exercise: SessionExercise(
          id: benchID, sessionId: sessionID, userId: userID,
          workoutId: "w1", name: "Barbell bench press", position: 0
        ),
        sets: [
          SessionSet(sessionExerciseId: benchID, userId: userID, setNumber: 1, weight: 60, reps: 10),
          SessionSet(sessionExerciseId: benchID, userId: userID, setNumber: 2, weight: 80, reps: 6, note: "Spotter"),
        ]
      ),
      SessionExerciseWithSets(
        exercise: SessionExercise(
          id: rowID, sessionId: sessionID, userId: userID,
          workoutId: nil, name: "Cable fly", position: 1
        ),
        sets: [
          SessionSet(sessionExerciseId: rowID, userId: userID, setNumber: 1, weight: nil, reps: 15),
        ]
      ),
    ]
  )

  return ActiveSessionView(model: .preview(session))
}
