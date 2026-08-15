import Foundation

// Direct-from-device Open Food Facts lookup — the FALLBACK used when the
// backend proxy fails, most often because OFF rate-limits the backend's shared
// Render egress IP while the device's own IP is fine.
//
// The normalization mirrors backend/src/services/barcode.service.js (and the
// web port in frontend/src/lib/openfoodfacts.ts) — if the shape or the rules
// change in one place, change all three. Error copy intentionally matches the
// backend's English messages, which is what the backend path surfaces today.
enum OpenFoodFactsDirect {
  private static let timeoutSeconds: TimeInterval = 8
  private static let userAgent = "Fuel/1.0 (Egypt nutrition tracker)"
  private static let fields = "product_name,brands,serving_size,serving_quantity,nutriments"
  private static let kjPerKcal = 4.184

  // timeoutIntervalForResource makes the 8s a WALL-CLOCK bound like the JS
  // ports' AbortController — URLRequest.timeoutInterval alone is an idle timer
  // that a slowly dripping response resets indefinitely.
  private static let session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = timeoutSeconds
    config.timeoutIntervalForResource = timeoutSeconds
    return URLSession(configuration: config)
  }()

  static func lookup(code: String) async throws -> BarcodeProduct {
    let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
    guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(encoded).json?fields=\(fields)") else {
      throw APIError.network
    }
    var request = URLRequest(url: url)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw APIError.server(
        message: "Couldn't reach the barcode database. Check your connection and try again.",
        status: 503
      )
    }
    guard let http = response as? HTTPURLResponse else { throw APIError.network }

    // v2 returns 404 for an unknown barcode (older paths use 200 + status:0,
    // handled below). Both mean "not in the database", not an outage.
    if http.statusCode == 404 { return notFound(code: code) }
    guard (200..<300).contains(http.statusCode) else {
      throw APIError.server(
        message: "The barcode database returned an error (status \(http.statusCode)). Try again shortly.",
        status: http.statusCode
      )
    }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw APIError.server(
        message: "The barcode database sent an unreadable response.",
        status: 503
      )
    }
    guard json["status"] as? Int == 1, let product = json["product"] as? [String: Any] else {
      return notFound(code: code)
    }

    let nutriments = product["nutriments"] as? [String: Any] ?? [:]
    let name = nullableString(product["product_name"])
    // First non-empty comma segment (split omits empty subsequences), matching
    // the JS ports' firstBrand — entries like ",Nestlé" exist in OFF data.
    let brand = (product["brands"] as? String)?
      .split(separator: ",")
      .compactMap { nullableString(String($0)) }
      .first

    let calories = kcalPer100(nutriments)
    // "Usable" means at least one whole calorie AFTER rounding — the same gate
    // the backend and its report validation apply. A product with only a name
    // is incomplete and the UI routes the user to the label-photo fallback.
    guard clampInt(calories) > 0 else { return incomplete(code: code, name: name, brand: brand) }

    return BarcodeProduct(
      found: true,
      ok: true,
      barcode: code,
      name: name,
      brand: brand,
      basis: .per100g,
      servingSize: nullableString(product["serving_size"]) ?? "",
      servingGrams: positiveNumber(product["serving_quantity"]),
      calories: clampInt(calories),
      protein: clampInt(anyDouble(nutriments["proteins_100g"]) ?? 0),
      carbs: clampInt(anyDouble(nutriments["carbohydrates_100g"]) ?? 0),
      fat: clampInt(anyDouble(nutriments["fat_100g"]) ?? 0),
      confidence: nil,
      note: brand.map { "\($0) · via Open Food Facts" } ?? "via Open Food Facts"
    )
  }

  // MARK: - Normalization helpers (ports of the backend's)

  /// Energy per 100g, always as kcal. OFF usually has energy-kcal_100g; if a
  /// product only carries kilojoules, convert.
  private static func kcalPer100(_ nutriments: [String: Any]) -> Double {
    if let kcal = anyDouble(nutriments["energy-kcal_100g"]) { return kcal }
    if let kj = anyDouble(nutriments["energy-kj_100g"]) ?? anyDouble(nutriments["energy_100g"]) {
      return kj / kjPerKcal
    }
    return 0
  }

  /// OFF presents numbers as JSON numbers OR numeric strings. Strings parse
  /// POSIX-style (`Double.init`), mirroring JS `Number()` in the web/backend
  /// ports — a locale-aware parse would accept "12,5" (or Arabic-Indic digits)
  /// that the JS ports reject, splitting behavior across platforms.
  private static func anyDouble(_ value: Any?) -> Double? {
    let parsed: Double?
    if let number = value as? NSNumber {
      parsed = number.doubleValue
    } else if let string = value as? String {
      parsed = Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
    } else {
      parsed = nil
    }
    // JS Number.isFinite parity: "Infinity"/"nan" strings parse in Swift but
    // must read as absent, like every other unusable value.
    guard let parsed, parsed.isFinite else { return nil }
    return parsed
  }

  private static func clampInt(_ value: Double) -> Double {
    let rounded = value.rounded()
    return rounded.isFinite && rounded >= 0 ? rounded : 0
  }

  private static func nullableString(_ value: Any?) -> String? {
    guard let string = value as? String else { return nil }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func positiveNumber(_ value: Any?) -> Double? {
    guard let number = anyDouble(value), number > 0 else { return nil }
    return number
  }

  private static func incomplete(code: String, name: String?, brand: String?) -> BarcodeProduct {
    BarcodeProduct(
      found: true, ok: false, barcode: code, name: name, brand: brand,
      basis: .per100g, servingSize: "", servingGrams: nil,
      calories: 0, protein: 0, carbs: 0, fat: 0, confidence: nil,
      note: "Found in the database, but it has no nutrition facts. Snap the label or enter the values."
    )
  }

  private static func notFound(code: String) -> BarcodeProduct {
    BarcodeProduct(
      found: false, ok: false, barcode: code, name: nil, brand: nil,
      basis: .per100g, servingSize: "", servingGrams: nil,
      calories: 0, protein: 0, carbs: 0, fat: 0, confidence: nil,
      note: "Not in the barcode database. Snap the nutrition label instead."
    )
  }
}
