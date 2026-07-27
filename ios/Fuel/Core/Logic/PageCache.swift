import Foundation

// The identity of a Library query: which category (nil = All), the trimmed
// search text, and whether we're looking at "My meals". Two queries that would
// return the same page share a cache entry. Pure Foundation so it's unit-tested.
struct CatalogQuery: Hashable, Sendable {
  var category: String?
  var search: String
  var mine: Bool

  init(category: String? = nil, search: String = "", mine: Bool = false) {
    self.category = category
    self.search = search
    self.mine = mine
  }
}

// A tiny generic, time-based cache used by the Library to hold loaded pages per
// query with a staleness policy (mirrors the web's 5-minute `invalidateMealsCache`
// module cache). Reads return nil once an entry is older than `staleness`;
// `invalidate()` drops everything after a catalog mutation.
struct PageCache<Key: Hashable, Value> {
  private struct Stored {
    let value: Value
    let storedAt: Date
  }

  private var storage: [Key: Stored] = [:]
  let staleness: TimeInterval

  init(staleness: TimeInterval = 300) {
    self.staleness = staleness
  }

  /// The cached value for `key`, or nil when missing or stale.
  func value(for key: Key, now: Date = Date()) -> Value? {
    guard let stored = storage[key] else { return nil }
    guard now.timeIntervalSince(stored.storedAt) <= staleness else { return nil }
    return stored.value
  }

  /// Whether a fresh (non-stale) entry exists for `key`.
  func isFresh(_ key: Key, now: Date = Date()) -> Bool {
    value(for: key, now: now) != nil
  }

  mutating func store(_ value: Value, for key: Key, now: Date = Date()) {
    storage[key] = Stored(value: value, storedAt: now)
  }

  /// Drop everything — called after any catalog create/edit/delete so every
  /// filter re-fetches fresh.
  mutating func invalidate() {
    storage.removeAll()
  }

  mutating func invalidate(_ key: Key) {
    storage.removeValue(forKey: key)
  }
}
