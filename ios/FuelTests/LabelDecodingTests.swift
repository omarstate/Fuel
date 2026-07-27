import Testing
import Foundation
@testable import Fuel

// Decoding fixtures shaped like the real M5 endpoint responses: barcode lookup
// (found=true with lenient string/number macros, and the found=false soft
// shape) and photo extraction (readable and the unreadable soft shape).
@Suite("Label DTO decoding")
struct LabelDecodingTests {
  private let decoder = JSONDecoder.fuel()

  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try decoder.decode(type, from: Data(json.utf8))
  }

  @Test("BarcodeProduct: found product with lenient string/number macros")
  func barcodeFound() throws {
    let json = #"""
    {
      "found": true, "ok": true, "barcode": "6224000123456",
      "name": "Chipsy Salt", "brand": "Chipsy",
      "basis": "per_100g", "servingSize": "1 bag (30 g)", "servingGrams": 30,
      "calories": "536", "protein": 7, "carbs": "53", "fat": 33,
      "confidence": null, "note": "Chipsy · via Open Food Facts"
    }
    """#
    let p = try decode(BarcodeProduct.self, json)
    #expect(p.found == true)
    #expect(p.ok == true)
    #expect(p.name == "Chipsy Salt")
    #expect(p.brand == "Chipsy")
    #expect(p.basis == .per100g)
    #expect(p.servingGrams == 30)
    #expect(p.calories == 536) // decoded from the string "536"
    #expect(p.carbs == 53)     // decoded from the string "53"
    #expect(p.fat == 33)
    #expect(p.confidence == nil)
  }

  @Test("BarcodeProduct: unknown code decodes the found=false soft shape")
  func barcodeNotFound() throws {
    let json = #"""
    {
      "found": false, "ok": false, "barcode": "0000000000000",
      "name": null, "brand": null,
      "basis": "per_100g", "servingSize": "", "servingGrams": null,
      "calories": 0, "protein": 0, "carbs": 0, "fat": 0,
      "confidence": null, "note": "Not in the barcode database. Snap the nutrition label instead."
    }
    """#
    let p = try decode(BarcodeProduct.self, json)
    #expect(p.found == false)
    #expect(p.ok == false)
    #expect(p.name == nil)
    #expect(p.brand == nil)
    #expect(p.servingGrams == nil)
    #expect(p.calories == 0)
    #expect(p.note.contains("nutrition label"))
  }

  @Test("BarcodeProduct: found-but-incomplete has ok=false with a name")
  func barcodeIncomplete() throws {
    let json = #"""
    {
      "found": true, "ok": false, "barcode": "6224000999999",
      "name": "Mystery Snack", "brand": null,
      "basis": "per_100g", "servingSize": "", "servingGrams": null,
      "calories": 0, "protein": 0, "carbs": 0, "fat": 0,
      "confidence": null, "note": "Found in the database, but it has no nutrition facts."
    }
    """#
    let p = try decode(BarcodeProduct.self, json)
    #expect(p.found == true)
    #expect(p.ok == false)
    #expect(p.name == "Mystery Snack")
  }

  @Test("ExtractedLabel: readable panel with confidence")
  func extractReadable() throws {
    let json = #"""
    {
      "ok": true, "readable": true, "name": "Greek Yogurt",
      "basis": "per_100g", "servingSize": "170 g", "servingGrams": 170,
      "calories": 59, "protein": 10, "carbs": 3.6, "fat": 0.4,
      "confidence": "high", "note": "Read the per-100g column."
    }
    """#
    let e = try decode(ExtractedLabel.self, json)
    #expect(e.ok == true)
    #expect(e.readable == true)
    #expect(e.name == "Greek Yogurt")
    #expect(e.basis == .per100g)
    #expect(e.servingGrams == 170)
    #expect(e.carbs == 3.6)
    #expect(e.confidence == .high)
  }

  @Test("ExtractedLabel: unreadable photo decodes the soft-fail shape")
  func extractUnreadable() throws {
    let json = #"""
    {
      "ok": false, "readable": false, "name": null,
      "basis": "per_serving", "servingSize": "", "servingGrams": null,
      "calories": 0, "protein": 0, "carbs": 0, "fat": 0,
      "confidence": null, "note": "Couldn't read this label. Retake the photo or enter the values manually."
    }
    """#
    let e = try decode(ExtractedLabel.self, json)
    #expect(e.ok == false)
    #expect(e.readable == false)
    #expect(e.name == nil)
    #expect(e.basis == .perServing)
    #expect(e.servingGrams == nil)
    #expect(e.calories == 0)
  }
}
