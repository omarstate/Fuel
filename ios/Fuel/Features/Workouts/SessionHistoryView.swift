import SwiftUI

// "My workouts" — the last 30 days of completed sessions as a scroll of cards,
// each opening the read-only detail. Port of
// workouts/session/session-history.tsx.
//
// This is a TAB ROOT on the workouts side, so it carries the same chrome as
// Library/History: hidden nav bar, editorial masthead, soft scroll edge,
// pull-to-refresh.
struct SessionHistoryView: View {
  @Environment(AppState.self) private var app
  @State private var model = SessionHistoryViewModel()

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          masthead

          if let error = model.error, model.sessions.isEmpty {
            ErrorBanner(
              error: error,
              onRetry: { Task { await model.refresh() } },
              onDismiss: { model.error = nil }
            )
          }

          if model.showSkeleton {
            ForEach(0..<3, id: \.self) { _ in
              SessionHistoryRow(session: .placeholder)
                .redacted(reason: .placeholder)
            }
          } else if model.isEmpty {
            emptyState
          } else {
            ForEach(model.sessions) { session in
              NavigationLink(value: session.id) {
                SessionHistoryRow(session: session)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .animation(.snappy, value: model.sessions.map(\.id))
      }
      .background(Color.fuelBackground)
      .scrollEdgeEffectStyle(.soft, for: .top)
      .toolbar(.hidden, for: .navigationBar)
      .statusBarFade()
      .refreshable { await model.refresh() }
      .navigationDestination(for: UUID.self) { id in
        SessionDetailView(sessionId: id)
      }
    }
    .task { await model.start() }
    // Ending a session on the Home tab bumps the revision, so this list is
    // already fresh when the user swipes over.
    .onChange(of: app.workoutRevision) { Task { await model.refresh() } }
  }

  // MARK: - Chrome

  private var masthead: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Workouts · History").fuelEyebrow(color: .fuelWorkoutInk)
        Text("My workouts")
          .font(.fuelMasthead)
          .foregroundStyle(Color.fuelInk)
      }
      Text("Every session you've completed in the last 30 days. Open one to see it exactly as you logged it.")
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
    }
    .padding(.bottom, 4)
  }

  // The start action lives on the workouts Home tab, so this is a signpost
  // rather than a button — offering "Start" here would need a category picker
  // this screen has no business owning.
  private var emptyState: some View {
    ContentUnavailableView {
      Label("No workouts yet", systemImage: "dumbbell")
    } description: {
      Text("Sessions you finish show up here. Start one from the Workouts tab.")
    }
    .padding(.top, 40)
  }
}

// MARK: - Row

// One completed session: the category it was started from, when it happened,
// and the three numbers that describe it. The whole card is the tap target.
struct SessionHistoryRow: View {
  let session: HistorySession
  /// Injected so previews and tests can pin "today".
  var now: Date = Date()

  private var durationText: String {
    guard let seconds = session.durationSeconds else { return "—" }
    return DurationFormat.elapsed(seconds)
  }

  private var startTime: String {
    session.startedAt.formatted(date: .omitted, time: .shortened)
  }

  private var relativeDay: String {
    switch WorkoutHistoryStats.relativeDay(session.startedAt, now: now) {
    case .today: return String(localized: "Today")
    case .yesterday: return String(localized: "Yesterday")
    case let .daysAgo(days): return String(localized: "\(days) days ago")
    case let .weeksAgo(weeks):
      return weeks == 1 ? String(localized: "1 week ago") : String(localized: "\(weeks) weeks ago")
    }
  }

  private var exercisesLabel: LocalizedStringKey {
    session.exerciseCount == 1 ? "1 exercise" : "\(session.exerciseCount) exercises"
  }

  private var setsLabel: LocalizedStringKey {
    session.setCount == 1 ? "1 set" : "\(session.setCount) sets"
  }

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          // A session started without a category (the web's "Session" fallback)
          // still gets a label — an unlabelled row reads like a bug.
          PillBadge(title: "\(session.categoryName ?? String(localized: "Session"))", tone: .workout)
          Text("\(relativeDay) · \(startTime)").fuelEyebrow()
          Spacer(minLength: 0)
        }

        HStack(spacing: 14) {
          stat("clock", durationText)
          stat("dumbbell", exercisesLabel)
          stat("square.stack.3d.up", setsLabel)
        }
      }

      Image(systemName: "chevron.right")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.fuelSubtle)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fuelCard()
    .contentShape(RoundedRectangle(cornerRadius: FuelRadius.card, style: .continuous))
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
  }

  private func stat(_ systemImage: String, _ text: String) -> some View {
    statRow(systemImage) {
      Text(text).font(.fuelMono(.caption, weight: 500))
    }
  }

  private func stat(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
    statRow(systemImage) {
      Text(text).font(.fuelMono(.caption, weight: 500))
    }
  }

  private func statRow(_ systemImage: String, @ViewBuilder label: () -> some View) -> some View {
    HStack(spacing: 5) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .semibold))
      label()
    }
    .foregroundStyle(Color.fuelSubtle)
  }
}

extension HistorySession {
  // Neutral shape behind the redacted first-load skeleton.
  static let placeholder = HistorySession(
    session: WorkoutSession(
      userId: UUID(),
      categoryName: "Push",
      status: .completed,
      startedAt: Date(),
      durationSeconds: 3_120
    ),
    exerciseCount: 5,
    setCount: 18
  )
}

#Preview("Rows") {
  let userID = UUID()
  let now = Date()
  return ScrollView {
    VStack(spacing: 12) {
      SessionHistoryRow(
        session: HistorySession(
          session: WorkoutSession(
            userId: userID, categoryName: "Push", status: .completed,
            startedAt: now.addingTimeInterval(-3 * 3_600), durationSeconds: 3_845
          ),
          exerciseCount: 5, setCount: 18
        ),
        now: now
      )
      SessionHistoryRow(
        session: HistorySession(
          session: WorkoutSession(
            userId: userID, categoryName: nil, status: .completed,
            startedAt: now.addingTimeInterval(-26 * 3_600), durationSeconds: nil
          ),
          exerciseCount: 1, setCount: 1
        ),
        now: now
      )
      SessionHistoryRow(
        session: HistorySession(
          session: WorkoutSession(
            userId: userID, categoryName: "Legs", status: .completed,
            startedAt: now.addingTimeInterval(-12 * 24 * 3_600), durationSeconds: 5_400
          ),
          exerciseCount: 7, setCount: 24
        ),
        now: now
      )
      SessionHistoryRow(session: .placeholder, now: now)
        .redacted(reason: .placeholder)
    }
    .padding()
  }
  .background(Color.fuelBackground)
}

#Preview("Screen") {
  SessionHistoryView()
    .environment(AppState())
}
