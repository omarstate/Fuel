import Foundation
import HealthKit

// Read-only Apple Health access. It started as one number (active energy for
// the Today hero); the workouts home now also shows today's steps and the
// latest heart rate (Apple Watch, iPhone motion — whatever writes to Health),
// so the permission sheet lists exactly these three read types. Fuel never
// writes to Health.
//
// Every failure path — Health unavailable on this device, permission denied,
// query error, no samples — resolves to zero/nil instead of throwing. Health
// numbers garnish the UI; they must never delay or fail the loads behind them.
@MainActor
final class HealthService {
  /// One instance for the whole app: HKHealthStore is not free to build, and a
  /// single instance keeps the ask-once authorization flag genuinely
  /// once-per-process (TodayViewModel and the workouts strip both read
  /// through this).
  static let shared = HealthService()

  private let store = HKHealthStore()
  private let activeEnergy = HKQuantityType(.activeEnergyBurned)
  private let stepCount = HKQuantityType(.stepCount)
  private let heartRate = HKQuantityType(.heartRate)
  /// Authorization is asked for once per process. The system remembers the
  /// answer (and re-shows nothing on a repeat call), so asking on every refresh
  /// would be pure overhead.
  private var didRequestAuthorization = false

  /// A snapshot of today's headline activity, for the workouts home strip.
  struct TodayActivity: Equatable, Sendable {
    var activeKilocalories = 0
    var steps = 0
    /// Most recent heart-rate sample recorded today; nil when there are no
    /// samples (or reads were denied — HealthKit makes those look identical).
    var heartRateBpm: Int?
    var heartRateAt: Date?
  }

  /// Kilocalories of active energy recorded today, rounded. 0 when Health is
  /// unavailable, unauthorized, or has nothing for today.
  func todayActiveEnergyBurned(now: Date = Date(), calendar: Calendar = .current) async -> Int {
    guard HKHealthStore.isHealthDataAvailable() else { return 0 }
    await requestAuthorizationIfNeeded()
    let start = DayBounds.startOfDay(now, calendar: calendar)
    let kcal = await cumulativeSum(of: activeEnergy, unit: .kilocalorie(), from: start, to: now)
    return positiveInt(kcal)
  }

  /// Today's kcal + steps + latest heart rate in one call, queried
  /// concurrently. Powers the workouts home "Activity today" strip.
  func todayActivity(now: Date = Date(), calendar: Calendar = .current) async -> TodayActivity {
    guard HKHealthStore.isHealthDataAvailable() else { return TodayActivity() }
    await requestAuthorizationIfNeeded()
    let start = DayBounds.startOfDay(now, calendar: calendar)

    async let kcal = cumulativeSum(of: activeEnergy, unit: .kilocalorie(), from: start, to: now)
    async let steps = cumulativeSum(of: stepCount, unit: .count(), from: start, to: now)
    async let heart = latestHeartRate(from: start, to: now)

    var activity = TodayActivity(
      activeKilocalories: positiveInt(await kcal),
      steps: positiveInt(await steps)
    )
    if let (bpm, at) = await heart, bpm.isFinite, bpm > 0 {
      activity.heartRateBpm = Int(bpm.rounded())
      activity.heartRateAt = at
    }
    return activity
  }

  // MARK: - Queries

  private func cumulativeSum(
    of type: HKQuantityType,
    unit: HKUnit,
    from start: Date,
    to end: Date
  ) async -> Double? {
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let store = self.store
    return await withCheckedContinuation { continuation in
      let query = HKStatisticsQuery(
        quantityType: type,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
      ) { _, statistics, _ in
        // A denied read looks exactly like "no samples" here, by design — HealthKit
        // never tells an app that data was withheld.
        continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
      }
      store.execute(query)
    }
  }

  /// The newest heart-rate sample in the window, reduced to Sendable parts
  /// inside the HealthKit callback.
  private func latestHeartRate(from start: Date, to end: Date) async -> (bpm: Double, at: Date)? {
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let type = heartRate
    let store = self.store
    return await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: 1,
        sortDescriptors: [sort]
      ) { _, samples, _ in
        guard let sample = samples?.first as? HKQuantitySample else {
          continuation.resume(returning: nil)
          return
        }
        let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        continuation.resume(returning: (bpm, sample.endDate))
      }
      store.execute(query)
    }
  }

  private func positiveInt(_ value: Double?) -> Int {
    guard let value, value.isFinite, value > 0 else { return 0 }
    return Int(value.rounded())
  }

  /// Whether this device has a Health store at all (iPhone yes, some iPads no).
  /// UI can hide Health surfaces entirely when this is false.
  static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

  /// Read-only request: `toShare` is empty, so Health shows only read rows.
  /// A denial resolves normally — the queries above then simply find nothing.
  /// The flag is set BEFORE the await to dedupe concurrent callers, but a
  /// throw resets it: a transient failure (e.g. the sheet couldn't present
  /// during launch) must not silence Health for the rest of the process.
  private func requestAuthorizationIfNeeded() async {
    guard !didRequestAuthorization else { return }
    didRequestAuthorization = true
    do {
      try await store.requestAuthorization(toShare: [], read: [activeEnergy, stepCount, heartRate])
    } catch {
      didRequestAuthorization = false
    }
  }
}
