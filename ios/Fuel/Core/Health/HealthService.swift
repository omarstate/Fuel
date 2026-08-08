import Foundation
import HealthKit

// Read-only Apple Health access, for exactly one number: the active energy the
// user has burned since local midnight, shown as "+N burned" in the Today hero.
// Fuel never writes to Health and never asks for a second type, so the system
// permission sheet stays one honest line long.
//
// Every failure path — Health unavailable on this device, permission denied,
// query error, no samples — resolves to 0 instead of throwing. Burned calories
// garnish the hero; they must never delay or fail the meal load behind them.
@MainActor
final class HealthService {
  private let store = HKHealthStore()
  private let activeEnergy = HKQuantityType(.activeEnergyBurned)
  /// Authorization is asked for once per process. The system remembers the
  /// answer (and re-shows nothing on a repeat call), so asking on every refresh
  /// would be pure overhead.
  private var didRequestAuthorization = false

  /// Kilocalories of active energy recorded today, rounded. 0 when Health is
  /// unavailable, unauthorized, or has nothing for today.
  func todayActiveEnergyBurned(now: Date = Date(), calendar: Calendar = .current) async -> Int {
    guard HKHealthStore.isHealthDataAvailable() else { return 0 }
    await requestAuthorizationIfNeeded()

    let start = DayBounds.startOfDay(now, calendar: calendar)
    let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
    let type = activeEnergy
    let store = self.store

    let kilocalories: Double? = await withCheckedContinuation { continuation in
      let query = HKStatisticsQuery(
        quantityType: type,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
      ) { _, statistics, _ in
        // A denied read looks exactly like "no samples" here, by design — HealthKit
        // never tells an app that data was withheld.
        continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()))
      }
      store.execute(query)
    }

    guard let kilocalories, kilocalories.isFinite, kilocalories > 0 else { return 0 }
    return Int(kilocalories.rounded())
  }

  /// Read-only request: `toShare` is empty, so Health shows a single read row.
  /// A denial resolves normally — the query above then simply finds nothing.
  private func requestAuthorizationIfNeeded() async {
    guard !didRequestAuthorization else { return }
    didRequestAuthorization = true
    try? await store.requestAuthorization(toShare: [], read: [activeEnergy])
  }
}
