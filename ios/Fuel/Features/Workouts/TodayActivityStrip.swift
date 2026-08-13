import SwiftUI

// The Apple Health strip on the workouts home: latest heart rate, active
// energy burned and steps for today — whatever the Apple Watch / iPhone wrote
// to Health. Deliberately self-contained (owns its HealthService, state and
// refresh loop) so WorkoutsHomeView only drops it into the stack.
//
// Freshness: Health totals move on their own as the watch syncs, so this
// refreshes every minute while visible and on foregrounding, not just on
// first appearance. All numbers fail soft — no Health access just reads as
// 0 / "—", never an error.
struct TodayActivityStrip: View {
  /// Bump from the parent (pull-to-refresh) to force an immediate re-read.
  var refreshTrigger = 0

  @Environment(\.scenePhase) private var scenePhase
  private let health = HealthService.shared
  @State private var activity: HealthService.TodayActivity?
  /// Foregrounding bumps this; combined with `refreshTrigger` it restarts the
  /// polling task, so there is exactly ONE refresh path and stale snapshots
  /// can never finish late and clobber fresher ones.
  @State private var wakeTick = 0

  /// Show when the latest heart-rate sample was recorded once it stops being
  /// "now" — a 7 AM reading at 11 PM must not pass for a live pulse.
  private var heartRateAge: String? {
    guard let at = activity?.heartRateAt, Date().timeIntervalSince(at) > 20 * 60 else { return nil }
    return at.formatted(.relative(presentation: .named))
  }

  var body: some View {
    // No Health store on this device → no strip, rather than fake zeros.
    if HealthService.isAvailable { strip }
  }

  private var strip: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Activity today").fuelEyebrow(color: .fuelWorkoutInk)
      HStack(spacing: 12) {
        StatTile(
          label: "Heart rate",
          value: activity?.heartRateBpm?.formatted() ?? "—",
          unit: "bpm",
          systemImage: "heart.fill",
          tint: .fuelWorkoutInk
        )
        StatTile(
          label: "Burned",
          value: (activity?.activeKilocalories ?? 0).formatted(),
          unit: "kcal",
          systemImage: "flame.fill",
          tint: .fuelGoldInk
        )
        StatTile(
          label: "Steps",
          value: (activity?.steps ?? 0).formatted(),
          systemImage: "figure.walk",
          tint: .fuelBlueInk
        )
      }
      if let heartRateAge {
        Text("Heart rate from \(heartRateAge)")
          .font(.fuelBody(.caption2))
          .foregroundStyle(Color.fuelSubtle)
      }
    }
    .redacted(reason: activity == nil ? .placeholder : [])
    // The ONLY refresh path: a polling loop that SwiftUI cancels and restarts
    // whenever the id changes (foregrounding, parent pull-to-refresh) — an
    // immediate re-read plus a fresh 60s cadence, with no second task racing.
    .task(id: refreshTrigger &+ wakeTick) {
      while !Task.isCancelled {
        activity = await health.todayActivity()
        try? await Task.sleep(for: .seconds(60))
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { wakeTick &+= 1 }
    }
  }
}

#Preview {
  TodayActivityStrip()
    .padding()
    .background(Color.fuelBackground)
}
