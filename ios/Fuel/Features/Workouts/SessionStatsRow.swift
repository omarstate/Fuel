import SwiftUI

// The three live counters above the exercise list — exercises, sets and total
// volume. Port of workouts/session/session-stats.tsx; the numbers come from
// SessionStats.totals so the header can never disagree with the cards below it.
// Volume is the accented tile, matching the web's highlighted third cell.
struct SessionStatsRow: View {
  let exercises: Int
  let sets: Int
  let volumeKg: Double

  var body: some View {
    HStack(spacing: 10) {
      StatTile(label: "Exercises", value: "\(exercises)")
      StatTile(label: "Sets", value: "\(sets)")
      StatTile(
        label: "Volume",
        value: DurationFormat.weight(volumeKg.rounded()),
        unit: "kg",
        systemImage: "scalemass.fill",
        tint: .fuelWorkoutInk
      )
    }
  }
}

#Preview {
  SessionStatsRow(exercises: 3, sets: 11, volumeKg: 4_820)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.fuelBackground)
}
