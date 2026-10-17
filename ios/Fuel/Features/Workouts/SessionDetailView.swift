import SwiftUI
import Observation

// A finished session, read-only — the receipt for one workout. Port of
// workouts/session/session-detail.tsx, pushed from SessionHistoryView (and
// presented in a sheet as the post-session summary).
//
// It refetches by id rather than taking the HistorySession row it was pushed
// from: the list embeds ids only (no sets), so the detail needs the full
// `session_exercises(*, session_sets(*))` tree anyway.
//
// Two actions live here: "Repeat workout" (primary — a fresh in_progress
// session with the same category and exercise list, presented full-screen the
// way the home tab presents one) and a toolbar delete (destructive, confirmed,
// pops back to history).
struct SessionDetailView: View {
  let sessionId: UUID

  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss

  @State private var model: SessionDetailModel
  @State private var confirmingDelete = false
  @State private var deleteTick = 0
  /// The repeated (or conflicting resumed) session shown full-screen.
  @State private var activeRoute: SessionRoute?
  /// The already-running session blocking a repeat — drives the conflict alert.
  @State private var conflictSession: WorkoutSession?
  /// Summary for a repeated session the user just ended (same sheet the home
  /// tab shows after ending).
  @State private var summaryRoute: SessionRoute?

  private let repository = WorkoutSessionRepository()

  init(sessionId: UUID) {
    self.sessionId = sessionId
    _model = State(initialValue: SessionDetailModel(sessionId: sessionId))
  }

  /// Preview/host seam for a model that already holds its session.
  init(model: SessionDetailModel) {
    self.sessionId = model.sessionId
    _model = State(initialValue: model)
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 16) {
        if let error = model.error {
          ErrorBanner(
            error: error,
            onRetry: { Task { await model.load() } },
            onDismiss: { model.error = nil }
          )
        }

        if let session = model.session {
          header(session)
          stats(session)
          if session.status == .completed {
            repeatButton(session)
          }
          if session.exercises.isEmpty {
            emptyExercises
          } else {
            SessionExerciseList(exercises: session.exercises)
          }
        } else if model.isLoading {
          skeleton
        } else if model.error == nil {
          notFound
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 24)
    }
    .background(Color.fuelBackground)
    .scrollEdgeEffectStyle(.soft, for: .top)
    .navigationTitle("Session")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(role: .destructive) {
          confirmingDelete = true
        } label: {
          Image(systemName: "trash")
        }
        .tint(.fuelDestructive)
        .disabled(model.session == nil)
        .accessibilityLabel("Delete session")
      }
    }
    .task {
      if model.session == nil { await model.load() }
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: deleteTick)
    .confirmationDialog(
      "Delete this session?",
      isPresented: $confirmingDelete,
      titleVisibility: .visible
    ) {
      Button("Delete session", role: .destructive) {
        Task { await deleteSession() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This session and everything logged in it will be removed from your history.")
    }
    // The repeat guard: never stack a second in_progress session. Jumping in
    // reuses the same full-screen route the repeat itself would take.
    .alert(
      "Finish your current session first",
      isPresented: Binding(get: { conflictSession != nil }, set: { if !$0 { conflictSession = nil } }),
      presenting: conflictSession
    ) { current in
      Button("Go to session") { activeRoute = SessionRoute(id: current.id) }
      Button("Cancel", role: .cancel) {}
    } message: { _ in
      Text("You already have a workout in progress. Jump back in and end it before starting a new one.")
    }
    .fullScreenCover(item: $activeRoute) { route in
      ActiveSessionView(sessionId: route.id) { endedId in
        activeRoute = nil
        summaryRoute = SessionRoute(id: endedId)
        app.bumpWorkoutRevision()
      }
    }
    .sheet(item: $summaryRoute) { route in
      NavigationStack { SessionDetailView(sessionId: route.id) }
    }
  }

  // MARK: - Actions

  /// Non-optimistic (meals-side split): delete in the DB, then leave — history
  /// refreshes off the revision bump rather than a stale local row.
  private func deleteSession() async {
    guard await model.deleteSession() else { return }
    deleteTick += 1
    app.bumpWorkoutRevision()
    dismiss()
  }

  /// Start a fresh session with this one's category + exercise list (no sets)
  /// and present it exactly like the home tab does. An in_progress session
  /// anywhere blocks it with the conflict alert instead of stacking a second.
  private func repeatWorkout(_ session: SessionWithExercises) async {
    do {
      if let current = try await repository.inProgressSession() {
        conflictSession = current
        return
      }
      let newId = try await repository.repeatSession(from: session)
      app.bumpWorkoutRevision()
      activeRoute = SessionRoute(id: newId)
    } catch {
      model.error = PresentableError.presentable(error)
    }
  }

  private func repeatButton(_ session: SessionWithExercises) -> some View {
    AsyncButton(
      style: .glassProminent,
      tint: .fuelWorkout,
      action: { await repeatWorkout(session) },
      onError: { _ in }
    ) {
      Label("Repeat workout", systemImage: "repeat")
        .font(.fuelBody(.body, weight: 600))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
  }

  // MARK: - Header

  private func header(_ session: SessionWithExercises) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      PillBadge(title: "\(session.categoryName ?? String(localized: "Session"))", tone: .workout)
      Text(FuelDateFormat.masthead(session.startedAt))
        .font(.fuelTitle)
        .foregroundStyle(Color.fuelInk)
      Text(timeLine(session))
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func timeLine(_ session: SessionWithExercises) -> String {
    let started = session.startedAt.formatted(date: .omitted, time: .shortened)
    guard let endedAt = session.endedAt else {
      return String(localized: "Started \(started)")
    }
    let finished = endedAt.formatted(date: .omitted, time: .shortened)
    return String(localized: "Started \(started) · finished \(finished)")
  }

  private func stats(_ session: SessionWithExercises) -> some View {
    HStack(spacing: 10) {
      StatTile(
        label: "Duration",
        value: durationText(session),
        unit: isDurationCapped(session) ? "auto-capped" : nil,
        systemImage: "clock",
        tint: .fuelWorkoutInk
      )
      StatTile(label: "Exercises", value: "\(session.exercises.count)")
      StatTile(label: "Sets", value: "\(session.exercises.reduce(0) { $0 + $1.sets.count })")
    }
  }

  /// Prefers the stored duration, falls back to the two timestamps — the same
  /// order session-detail.tsx uses, so an old row written before
  /// `duration_seconds` existed still reads correctly.
  private func durationSeconds(_ session: SessionWithExercises) -> Int? {
    if let seconds = session.durationSeconds { return seconds }
    guard let endedAt = session.endedAt else { return nil }
    return Int(endedAt.timeIntervalSince(session.startedAt).rounded())
  }

  /// Over the 6h display cap the tile reads "6h+ auto-capped" — a 71h stored
  /// duration means "never ended", and repeating it as fact would be a lie.
  /// Display only; the row keeps its real numbers.
  private func durationText(_ session: SessionWithExercises) -> String {
    guard let seconds = durationSeconds(session) else { return "—" }
    return DurationFormat.elapsedDisplay(seconds)
  }

  private func isDurationCapped(_ session: SessionWithExercises) -> Bool {
    (durationSeconds(session) ?? 0) > DurationFormat.displayCapSeconds
  }

  // MARK: - States

  private var emptyExercises: some View {
    ContentUnavailableView {
      Label("No exercises logged", systemImage: "dumbbell")
    } description: {
      Text("This session was ended without logging anything.")
    }
    .padding(.top, 24)
  }

  private var notFound: some View {
    ContentUnavailableView {
      Label("Session not found", systemImage: "questionmark.folder")
    } description: {
      Text("It may have been removed from another device.")
    }
    .padding(.top, 40)
  }

  private var skeleton: some View {
    VStack(alignment: .leading, spacing: 16) {
      header(.placeholder)
      stats(.placeholder)
      SessionExerciseList(exercises: SessionWithExercises.placeholder.exercises)
    }
    .redacted(reason: .placeholder)
  }
}

/// Identifiable wrapper so a bare session UUID can drive `.fullScreenCover(item:)`
/// and `.sheet(item:)` (same shape as the home tab's private wrapper).
private struct SessionRoute: Identifiable {
  let id: UUID
}

// MARK: - Model

// Deliberately tiny: one fetch, four pieces of state. History rows are
// immutable, so there is nothing to reconcile and no optimistic anything —
// including the delete, which is DB-first and leaves local state to the pop.
@MainActor
@Observable
final class SessionDetailModel {
  let sessionId: UUID
  private let repo = WorkoutSessionRepository()

  private(set) var session: SessionWithExercises?
  private(set) var isLoading = false
  var error: PresentableError?

  init(sessionId: UUID, session: SessionWithExercises? = nil) {
    self.sessionId = sessionId
    self.session = session
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      session = try await repo.session(id: sessionId)
      error = nil
    } catch {
      self.error = PresentableError(error)
    }
  }

  /// The DB half of the non-optimistic delete; exercises and sets cascade.
  func deleteSession() async -> Bool {
    do {
      try await repo.deleteSession(id: sessionId)
      return true
    } catch {
      self.error = PresentableError(error)
      return false
    }
  }
}

extension SessionWithExercises {
  // Shape-only stand-in for the redacted first-load skeleton.
  static let placeholder: SessionWithExercises = {
    let sessionID = UUID()
    let userID = UUID()
    let exerciseID = UUID()
    return SessionWithExercises(
      session: WorkoutSession(
        id: sessionID, userId: userID, categoryName: "Push",
        status: .completed, startedAt: Date(), endedAt: Date(), durationSeconds: 3_600
      ),
      exercises: [
        SessionExerciseWithSets(
          exercise: SessionExercise(
            id: exerciseID, sessionId: sessionID, userId: userID,
            workoutId: "w", name: "Exercise name", position: 0
          ),
          sets: [
            SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 1, weight: 60, reps: 10),
            SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 2, weight: 60, reps: 10),
          ]
        )
      ]
    )
  }()
}

#Preview("Loaded") {
  let sessionID = UUID()
  let userID = UUID()
  let benchID = UUID()
  let squatID = UUID()
  let session = SessionWithExercises(
    session: WorkoutSession(
      id: sessionID, userId: userID, categoryName: "Push", categorySlug: "push",
      status: .completed,
      startedAt: Date().addingTimeInterval(-5_400),
      endedAt: Date().addingTimeInterval(-1_500),
      durationSeconds: 3_900
    ),
    exercises: [
      SessionExerciseWithSets(
        exercise: SessionExercise(
          id: benchID, sessionId: sessionID, userId: userID,
          workoutId: "w1", name: "Bench press", position: 0
        ),
        sets: [
          SessionSet(sessionExerciseId: benchID, userId: userID, setNumber: 1, weight: 80, reps: 8),
          SessionSet(sessionExerciseId: benchID, userId: userID, setNumber: 2, weight: 82.5, reps: 6, note: "Spotter on the last rep"),
        ]
      ),
      SessionExerciseWithSets(
        exercise: SessionExercise(
          id: squatID, sessionId: sessionID, userId: userID,
          workoutId: nil, name: "Landmine press", position: 1
        ),
        sets: [
          SessionSet(sessionExerciseId: squatID, userId: userID, setNumber: 1, weight: nil, reps: 15),
        ]
      ),
    ]
  )
  return NavigationStack {
    SessionDetailView(model: SessionDetailModel(sessionId: sessionID, session: session))
  }
  .environment(AppState())
}
