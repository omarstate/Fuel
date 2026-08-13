import SwiftUI
import Observation

// A finished session, read-only — the receipt for one workout. Port of
// workouts/session/session-detail.tsx, pushed from SessionHistoryView.
//
// It refetches by id rather than taking the HistorySession row it was pushed
// from: the list embeds ids only (no sets), so the detail needs the full
// `session_exercises(*, session_sets(*))` tree anyway.
struct SessionDetailView: View {
  let sessionId: UUID

  @State private var model: SessionDetailModel

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
    .task {
      if model.session == nil { await model.load() }
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
  private func durationText(_ session: SessionWithExercises) -> String {
    if let seconds = session.durationSeconds { return DurationFormat.elapsed(seconds) }
    guard let endedAt = session.endedAt else { return "—" }
    return DurationFormat.elapsed(Int(endedAt.timeIntervalSince(session.startedAt).rounded()))
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

// MARK: - Model

// Deliberately tiny: one fetch, three pieces of state. History rows are
// immutable, so there is nothing to reconcile and no optimistic anything.
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
}
