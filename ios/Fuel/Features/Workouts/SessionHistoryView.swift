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
  @State private var pendingDelete: HistorySession?
  @State private var deleteTick = 0

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          masthead

          // No isEmpty gate (matches the meals History banner): a failed
          // delete must surface even when the list still has rows.
          if let error = model.error {
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
              // Cards in a ScrollView have no swipe actions — like the Today
              // meal rows, the long-press menu routes through the same
              // confirmation dialog as any other destructive action.
              .contextMenu {
                Button(role: .destructive) {
                  pendingDelete = session
                } label: {
                  Label("Delete session", systemImage: "trash")
                }
              }
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
    .sensoryFeedback(.impact(weight: .medium), trigger: deleteTick)
    .confirmationDialog(
      "Delete this session?",
      isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
      titleVisibility: .visible,
      presenting: pendingDelete
    ) { session in
      Button("Delete session", role: .destructive) { delete(session) }
      Button("Cancel", role: .cancel) { pendingDelete = nil }
    } message: { _ in
      Text("This session and everything logged in it will be removed from your history.")
    }
  }

  // Non-optimistic: the row only animates out after the DB delete lands (the
  // model's deleteSession is DB-then-drop).
  private func delete(_ session: HistorySession) {
    Task {
      guard await model.deleteSession(session) else { return }
      deleteTick += 1
      app.bumpWorkoutRevision()
    }
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

  // Durations over the 6h display cap mean "never ended", so the row says
  // "6h+ · auto-capped" instead of parroting a 71-hour number (display only —
  // the stored row is untouched).
  private var durationText: String {
    guard let seconds = session.durationSeconds else { return "—" }
    return DurationFormat.elapsedDisplay(seconds)
  }

  private var isDurationCapped: Bool {
    (session.durationSeconds ?? 0) > DurationFormat.displayCapSeconds
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
          HStack(spacing: 5) {
            stat("clock", durationText)
            if isDurationCapped {
              Text("auto-capped")
                .font(.fuelBody(.caption2))
                .foregroundStyle(Color.fuelSubtle.opacity(0.8))
            }
          }
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
      // The forgot-to-end shape from real data (71h) — reads "6h+ · auto-capped".
      SessionHistoryRow(
        session: HistorySession(
          session: WorkoutSession(
            userId: userID, categoryName: "Pull", status: .completed,
            startedAt: now.addingTimeInterval(-5 * 24 * 3_600), durationSeconds: 258_034
          ),
          exerciseCount: 4, setCount: 11
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
