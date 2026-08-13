import SwiftUI

// The live "how long has this been going" readout for an in-flight session.
// Port of workouts/session/session-timer.tsx, with the same guarantee: the
// elapsed time is DERIVED from `startedAt` on every tick, never accumulated in a
// counter, so backgrounding the app (or the timer missing ticks under load)
// cannot make it drift. TimelineView drives the redraws; SessionStats owns the
// arithmetic and DurationFormat the H:MM:SS shape.
struct SessionTimerView: View {
  let startedAt: Date
  var font: Font = .fuelStatNumber
  var color: Color = .fuelInk

  var body: some View {
    TimelineView(.periodic(from: startedAt, by: 1)) { context in
      Text(DurationFormat.elapsed(SessionStats.elapsedSeconds(from: startedAt, to: context.date)))
        .font(font)
        .foregroundStyle(color)
        .contentTransition(.numericText())
        // A machine readout, so it stays LTR even in Arabic.
        .environment(\.layoutDirection, .leftToRight)
    }
    .accessibilityLabel("Elapsed session time")
  }
}

#Preview {
  VStack(spacing: 20) {
    SessionTimerView(startedAt: Date().addingTimeInterval(-2_710))
    SessionTimerView(startedAt: Date().addingTimeInterval(-45), font: .fuelMetric, color: .fuelWorkoutInk)
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
