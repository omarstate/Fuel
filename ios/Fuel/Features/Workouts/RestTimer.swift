import Foundation
import Observation
import AudioToolbox
import UserNotifications

// The between-sets rest countdown. Port of the `useRestTimer` hook in
// workouts/session/rest-timer.tsx, with the web's central guarantee kept intact:
// the remaining seconds are ALWAYS derived from an end timestamp, never counted
// down in a variable, so a backgrounded or throttled app resumes showing the
// truth.
//
// Zero is announced through three independent channels, because a gym phone can
// be in any of three states:
//   1. foreground — one cancellable Task sleeping until `endsAt`,
//   2. backgrounded/locked — a local notification scheduled at the same instant,
//   3. in a pocket — the haptic + system sound the view fires off `finishTrigger`.
// They are deliberately redundant; whichever the user is reachable by wins.
@MainActor
@Observable
final class RestTimer {
  enum Phase: Equatable {
    case idle
    case running
    /// The brief "GO" flash after zero, before falling back to idle.
    case done
  }

  /// Bounds for the configurable rest length, stepped ±30s from the idle bar.
  static let durationRange = 30...600
  static let durationStep = 30
  static let defaultDuration = 120

  /// One fixed identifier, so scheduling again always replaces the pending
  /// notification instead of stacking a second alert on top of it.
  private static let notificationID = "fuel.rest.timer"
  private static var didRequestAuthorization = false

  private enum Keys {
    static let duration = "fuel.rest.duration"
    static let sound = "fuel.rest.sound"
  }

  private(set) var phase: Phase = .idle
  /// The instant this rest ends. nil whenever nothing is running.
  private(set) var endsAt: Date?
  /// The full length of the current rest, for the progress line. Never shrinks
  /// below the remaining time, so `+15s` can't push the ratio past 1.
  private(set) var total = 90
  /// Bumped per rest, purely to vary which quote the bar starts on (web `restCount`).
  private(set) var restCount = 0
  /// Toggled when a rest reaches zero — the view observes it with
  /// `.sensoryFeedback(.success, trigger:)`.
  private(set) var finishTrigger = 0

  /// The chosen rest length, persisted across launches.
  var duration: Int {
    didSet { defaults.set(duration, forKey: Keys.duration) }
  }

  /// Whether zero plays a sound, persisted across launches.
  var soundOn: Bool {
    didSet { defaults.set(soundOn, forKey: Keys.sound) }
  }

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private var countdown: Task<Void, Never>?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let stored = defaults.integer(forKey: Keys.duration)
    // An out-of-range or missing stored value falls back to the 2:00 default.
    self.duration = Self.durationRange.contains(stored) ? stored : Self.defaultDuration
    self.soundOn = defaults.object(forKey: Keys.sound) as? Bool ?? true
    self.total = self.duration
  }

  // MARK: - Derived

  /// Seconds left at `date`. Ceil, so a rest reads "1:30" for its whole first
  /// second rather than flashing "1:29" immediately (matches the web's ceil).
  func remaining(at date: Date) -> Int {
    guard let endsAt else { return 0 }
    return max(0, Int(endsAt.timeIntervalSince(date).rounded(.up)))
  }

  /// 1 → just started, 0 → done. Clamped, for the progress line.
  func progress(at date: Date) -> Double {
    guard total > 0 else { return 0 }
    return min(1, max(0, Double(remaining(at: date)) / Double(total)))
  }

  /// The last five seconds get the accent treatment in the bar.
  func isFinalCountdown(at date: Date) -> Bool {
    phase == .running && remaining(at: date) <= 5
  }

  // MARK: - Controls

  /// Begin (or replace) a rest. Called automatically after a logged set and
  /// manually from the bar's play button.
  func start(seconds: Int? = nil) {
    let length = max(5, seconds ?? duration)
    total = length
    restCount += 1
    schedule(endingAt: Date().addingTimeInterval(TimeInterval(length)))
  }

  /// Step the configured rest length by ±30s while idle, clamped to the range.
  func bumpDuration(by delta: Int) {
    duration = min(max(duration + delta, Self.durationRange.lowerBound), Self.durationRange.upperBound)
  }

  /// Restart the current rest from the top.
  func restart() {
    start()
  }

  /// Move the end instant by ±15s, never leaving fewer than 5 seconds on the
  /// clock (a "−15" on 8 seconds shortens to 5, it does not fire immediately).
  func adjust(by delta: Int) {
    guard phase == .running, let endsAt else { return }
    let candidate = endsAt.addingTimeInterval(TimeInterval(delta))
    let floor = Date().addingTimeInterval(5)
    schedule(endingAt: max(candidate, floor))
  }

  /// Abandon the rest — back to idle with nothing pending anywhere.
  func skip() {
    countdown?.cancel()
    countdown = nil
    cancelPendingNotification()
    endsAt = nil
    phase = .idle
  }

  /// Tear everything down without touching the phase-dependent UI — used when
  /// the session ends, so no notification can fire after the user has left.
  func cancelPendingNotification() {
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
  }

  // MARK: - Internals

  private func schedule(endingAt date: Date) {
    countdown?.cancel()
    endsAt = date
    phase = .running
    total = max(total, remaining(at: Date()))
    scheduleNotification(at: date)

    countdown = Task { [weak self] in
      let seconds = max(0, date.timeIntervalSinceNow)
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled, let self else { return }
      self.finish()
      // The "GO" flash is transient; drop back to idle on its own.
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled, self.phase == .done else { return }
      self.phase = .idle
    }
  }

  private func finish() {
    endsAt = nil
    phase = .done
    finishTrigger += 1
    cancelPendingNotification()
    if soundOn {
      // A short system tone — no bundled asset and no AVAudioSession to
      // configure, so it can never disturb the user's own music session.
      AudioServicesPlaySystemSound(1054)
    }
  }

  // Fires while the app is backgrounded or locked. Authorization is requested
  // the first time a rest actually starts — never at launch — and a denial is a
  // no-op: the foreground Task and the haptic still work.
  private func scheduleNotification(at date: Date) {
    guard date.timeIntervalSinceNow > 0.5 else { return }
    let center = UNUserNotificationCenter.current()
    let withSound = soundOn

    Task {
      if !Self.didRequestAuthorization {
        Self.didRequestAuthorization = true
        center.delegate = RestNotificationDelegate.shared
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
      }
      // Authorization can take a while — re-derive the delay from the target
      // instant rather than trusting the one measured before the prompt.
      let interval = date.timeIntervalSinceNow
      guard interval > 0.5 else { return }

      let content = UNMutableNotificationContent()
      content.title = String(localized: "Rest over")
      content.body = String(localized: "Time for the next set.")
      content.sound = withSound ? .default : nil

      center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
      let request = UNNotificationRequest(
        identifier: Self.notificationID,
        content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
      )
      try? await center.add(request)
    }
  }
}

// The smallest possible delegate: without one, iOS suppresses the banner while
// the app is frontmost, which is exactly the case that matters when the phone is
// face-down on a bench. Installed from RestTimer's first `start()` so FuelApp
// stays untouched — nothing app-level is needed for a feature this local.
private final class RestNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  static let shared = RestNotificationDelegate()

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
