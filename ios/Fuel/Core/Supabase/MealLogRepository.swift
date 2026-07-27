import Foundation
import Supabase

// CRUD on public.meals via the supabase-swift client (PostgREST, RLS own-row).
// Mirrors the contract in frontend/src/app-editorial/use-meals.ts +
// use-streaks.ts + use-week-meals.ts: local-day ranges for Today, a 30-day
// window for History, and a 180-day daily-total aggregate for streaks. The same
// live table backs the web app, so writes appear there instantly and vice versa.
struct MealLogRepository: Sendable {
  private var client: SupabaseClient { SupabaseService.shared.client }

  /// The signed-in user's id, fetched fresh from the session (never cached).
  func userID() async throws -> UUID {
    try await SupabaseService.shared.auth.session.user.id
  }

  // MARK: - Reads

  /// Today's log — every meal within `date`'s local calendar day, newest first.
  func meals(on date: Date, calendar: Calendar = .current) async throws -> [LoggedMeal] {
    let userID = try await userID()
    let start = DayBounds.startOfDay(date, calendar: calendar)
    let end = DayBounds.addDays(start, 1, calendar: calendar)
    return try await client
      .from("meals")
      .select()
      .eq("user_id", value: userID.uuidString)
      .gte("logged_at", value: iso(start))
      .lt("logged_at", value: iso(end))
      .order("logged_at", ascending: false)
      .execute()
      .value
  }

  /// The last `days` calendar days of logs (default 30), newest first — History.
  func recentMeals(days: Int = 30, now: Date = Date(), calendar: Calendar = .current) async throws -> [LoggedMeal] {
    let userID = try await userID()
    let since = DayBounds.addDays(DayBounds.startOfDay(now, calendar: calendar), -(days - 1), calendar: calendar)
    return try await client
      .from("meals")
      .select()
      .eq("user_id", value: userID.uuidString)
      .gte("logged_at", value: iso(since))
      .order("logged_at", ascending: false)
      .execute()
      .value
  }

  /// Per-local-day calorie totals over the streak window (default 180 days),
  /// aggregated client-side into dayKey → kcal for Streaks.compute.
  func dailyCalorieTotals(days: Int = Streaks.historyDays, now: Date = Date(), calendar: Calendar = .current) async throws -> [String: Int] {
    let userID = try await userID()
    let since = DayBounds.addDays(DayBounds.startOfDay(now, calendar: calendar), -days, calendar: calendar)
    let rows: [CalorieRow] = try await client
      .from("meals")
      .select("calories, logged_at")
      .eq("user_id", value: userID.uuidString)
      .gte("logged_at", value: iso(since))
      .execute()
      .value
    var perDay: [String: Int] = [:]
    for row in rows {
      perDay[DayBounds.dayKey(row.loggedAt, calendar: calendar), default: 0] += row.calories
    }
    return perDay
  }

  // MARK: - Writes

  /// Insert a client-generated row. `meal.userId` must be the session user for
  /// RLS to accept it — build it with `userID()`.
  func insert(_ meal: LoggedMeal) async throws {
    try await client.from("meals").insert(meal).execute()
  }

  /// DB delete only — callers remove from local state optimistically and roll
  /// back on throw, matching the web app's non-optimistic split.
  func delete(id: UUID) async throws {
    try await client.from("meals").delete().eq("id", value: id.uuidString).execute()
  }

  // MARK: - Helpers

  private func iso(_ date: Date) -> String {
    ISO8601DateFormatter.fuelWithFractional.string(from: date)
  }

  // Lightweight projection for the streak aggregate (calories + timestamp only).
  private struct CalorieRow: Decodable {
    let calories: Int
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
      case calories
      case loggedAt = "logged_at"
    }

    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      if let i = try? c.decode(Int.self, forKey: .calories) {
        calories = i
      } else {
        calories = Int((try c.decode(Double.self, forKey: .calories)).rounded())
      }
      let raw = try c.decode(String.self, forKey: .loggedAt)
      guard let d = ISO8601DateFormatter.fuelWithFractional.date(from: raw)
        ?? ISO8601DateFormatter.fuelPlain.date(from: raw) else {
        throw DecodingError.dataCorruptedError(
          forKey: .loggedAt, in: c,
          debugDescription: "Unrecognized logged_at timestamp: \(raw)"
        )
      }
      loggedAt = d
    }
  }
}
