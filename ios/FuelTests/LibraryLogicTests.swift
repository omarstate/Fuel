import Testing
import Foundation
@testable import Fuel

// PageCache staleness/keying/invalidation and the add-to-log serving scaling.
@Suite("Library logic")
struct LibraryLogicTests {

  // MARK: - PageCache

  @Test("Fresh value is returned, stale value is dropped")
  func staleness() {
    var cache = PageCache<CatalogQuery, [Int]>(staleness: 300)
    let key = CatalogQuery(category: "egyptian", search: "", mine: false)
    let t0 = Date(timeIntervalSince1970: 1_000)
    cache.store([1, 2, 3], for: key, now: t0)

    // Within the window.
    #expect(cache.value(for: key, now: t0.addingTimeInterval(299)) == [1, 2, 3])
    #expect(cache.isFresh(key, now: t0.addingTimeInterval(300)) == true)
    // Past the window.
    #expect(cache.value(for: key, now: t0.addingTimeInterval(301)) == nil)
    #expect(cache.isFresh(key, now: t0.addingTimeInterval(301)) == false)
  }

  @Test("Distinct query keys don't collide")
  func keying() {
    var cache = PageCache<CatalogQuery, String>()
    let now = Date()
    let all = CatalogQuery(category: nil, search: "", mine: false)
    let egyptian = CatalogQuery(category: "egyptian", search: "", mine: false)
    let searched = CatalogQuery(category: nil, search: "kosh", mine: false)
    let mine = CatalogQuery(category: nil, search: "", mine: true)

    cache.store("all", for: all, now: now)
    cache.store("egy", for: egyptian, now: now)
    cache.store("srch", for: searched, now: now)
    cache.store("mine", for: mine, now: now)

    #expect(cache.value(for: all, now: now) == "all")
    #expect(cache.value(for: egyptian, now: now) == "egy")
    #expect(cache.value(for: searched, now: now) == "srch")
    #expect(cache.value(for: mine, now: now) == "mine")
  }

  @Test("invalidate clears everything; targeted invalidate clears one key")
  func invalidation() {
    var cache = PageCache<CatalogQuery, Int>()
    let now = Date()
    let a = CatalogQuery(category: "a")
    let b = CatalogQuery(category: "b")
    cache.store(1, for: a, now: now)
    cache.store(2, for: b, now: now)

    cache.invalidate(a)
    #expect(cache.value(for: a, now: now) == nil)
    #expect(cache.value(for: b, now: now) == 2)

    cache.invalidate()
    #expect(cache.value(for: b, now: now) == nil)
  }

  // MARK: - PortionScaling

  @Test("scaledInt rounds to the nearest integer")
  func scaledIntRounding() {
    #expect(PortionScaling.scaledInt(720, factor: 1) == 720)
    #expect(PortionScaling.scaledInt(720, factor: 0.5) == 360)
    #expect(PortionScaling.scaledInt(165, factor: 0.5) == 83)   // 82.5 → 83 (half away from zero)
    #expect(PortionScaling.scaledInt(31, factor: 1.5) == 47)    // 46.5 → 47
    #expect(PortionScaling.scaledInt(14, factor: 3) == 42)
    #expect(PortionScaling.scaledInt(0, factor: 2) == 0)
  }

  @Test("macros scale each field independently and round")
  func macrosScaling() {
    let scaled = PortionScaling.macros(
      calories: 720, protein: 22, carbs: 120, fat: 14, factor: 1.5
    )
    #expect(scaled.calories == 1080)
    #expect(scaled.protein == 33)
    #expect(scaled.carbs == 180)
    #expect(scaled.fat == 21)
  }

  @Test("factorLabel keeps whole numbers whole and halves to one decimal")
  func factorLabel() {
    #expect(PortionScaling.factorLabel(1) == "1")
    #expect(PortionScaling.factorLabel(2) == "2")
    #expect(PortionScaling.factorLabel(0.5) == "0.5")
    #expect(PortionScaling.factorLabel(1.5) == "1.5")
  }
}
