import Foundation

// Typed helpers for the routes this milestone touches. Thin wrappers over
// APIClient so call sites read like the API contract.
enum FuelAPI {
  static func me() async throws -> Me {
    try await APIClient.shared.get("me")
  }

  /// GET /profile -> Profile | null. A null body decodes to nil.
  static func profile() async throws -> Profile? {
    try await APIClient.shared.get("profile")
  }

  /// PUT /profile with the camelCase ProfileInput body; server recomputes targets.
  static func saveProfile(_ input: ProfileInput) async throws -> Profile {
    try await APIClient.shared.put("profile", body: input)
  }

  struct DeleteResult: Decodable { let deleted: Bool }

  @discardableResult
  static func deleteAccount() async throws -> DeleteResult {
    try await APIClient.shared.delete("me")
  }

  // MARK: - Catalog (M3)

  /// GET /categories (public) -> [Category].
  static func categories() async throws -> [Category] {
    try await APIClient.shared.get("categories", authorized: false)
  }

  /// GET /meals (public) -> { data: [CatalogMeal], count }. Omits empty filters.
  static func meals(
    category: String?,
    search: String,
    limit: Int,
    offset: Int
  ) async throws -> (items: [CatalogMeal], count: Int) {
    var query: [URLQueryItem] = [
      URLQueryItem(name: "limit", value: String(limit)),
      URLQueryItem(name: "offset", value: String(offset)),
    ]
    if let category, !category.isEmpty {
      query.append(URLQueryItem(name: "category", value: category))
    }
    let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      query.append(URLQueryItem(name: "search", value: trimmed))
    }
    return try await APIClient.shared.list("meals", query: query, authorized: false)
  }

  /// GET /meals/mine (auth) -> [CatalogMeal] the signed-in user created.
  static func myMeals() async throws -> [CatalogMeal] {
    try await APIClient.shared.get("meals/mine")
  }

  /// GET /meals/:id (public) -> CatalogMealDetail; 404 if missing.
  static func mealDetail(id: String) async throws -> CatalogMealDetail {
    try await APIClient.shared.get("meals/\(id)", authorized: false)
  }

  /// POST /meals (auth) -> the created CatalogMeal.
  static func createMeal(_ input: CatalogMealInput) async throws -> CatalogMeal {
    try await APIClient.shared.post("meals", body: input)
  }

  /// PATCH /meals/:id (auth; creator or admin) -> the updated CatalogMeal.
  static func updateMeal(id: String, _ input: CatalogMealInput) async throws -> CatalogMeal {
    try await APIClient.shared.patch("meals/\(id)", body: input)
  }

  struct DeletedMeal: Decodable { let id: String }

  /// DELETE /meals/:id (auth; creator or admin).
  @discardableResult
  static func deleteMeal(id: String) async throws -> DeletedMeal {
    try await APIClient.shared.delete("meals/\(id)")
  }

  // MARK: - AI (M4)

  /// GET /ai/insights (auth) -> AiInsights. `refresh` bypasses the daily cache.
  static func insights(refresh: Bool = false, lang: String = AppLanguage.current) async throws -> AiInsights {
    var query = [URLQueryItem(name: "lang", value: lang)]
    if refresh { query.append(URLQueryItem(name: "refresh", value: "1")) }
    return try await APIClient.shared.get("ai/insights", query: query)
  }

  /// POST /ai/meals/suggest (auth) -> SuggestResponse. Deterministic + fast.
  static func suggestMeals(remaining: RemainingMacros, lang: String = AppLanguage.current) async throws -> SuggestResponse {
    try await APIClient.shared.post("ai/meals/suggest", body: SuggestBody(remaining: remaining, lang: lang))
  }

  /// POST /ai/meals/lookup (auth) -> AiLookupResponse. Grounded search; slow.
  static func lookupMeals(query: String, lang: String = AppLanguage.current) async throws -> AiLookupResponse {
    try await APIClient.shared.post("ai/meals/lookup", body: LookupBody(query: query, lang: lang))
  }

  /// POST /meals/estimate (auth) -> [EstimatedMeal] in input order. Slow.
  static func estimateMeals(place: String?, items: [String], lang: String = AppLanguage.current) async throws -> [EstimatedMeal] {
    try await APIClient.shared.post("meals/estimate", body: EstimateBody(place: place, items: items, lang: lang))
  }

  /// POST /meals/ai-catalog (auth) -> [CatalogMeal]. Best-effort catalog save.
  @discardableResult
  static func saveAiCatalog(meals: [AiCatalogMealInput]) async throws -> [CatalogMeal] {
    try await APIClient.shared.post("meals/ai-catalog", body: AiCatalogBody(meals: meals))
  }

  // MARK: - Scan (M5)

  /// GET /meals/barcode/:code (auth) -> BarcodeProduct. `code` is 8–14 digits;
  /// an unknown code comes back as `found: false` (soft state), a real outage as
  /// a 503. Percent-encodes the code defensively even though it's digits-only.
  static func barcodeLookup(code: String) async throws -> BarcodeProduct {
    let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
    return try await APIClient.shared.get("meals/barcode/\(encoded)")
  }

  /// POST /meals/photo-extract (auth) -> ExtractedLabel. `imageBase64` is raw
  /// base64 (no data: prefix). Slow (Gemini vision, 10–40s); a bad photo returns
  /// `readable: false` (soft state), never an error.
  static func extractLabel(imageBase64: String, mimeType: String = "image/jpeg") async throws -> ExtractedLabel {
    try await APIClient.shared.post("meals/photo-extract", body: PhotoExtractBody(image: imageBase64, mimeType: mimeType))
  }

  // MARK: - Voice logging

  /// POST /ai/meals/voice-log (auth) -> VoiceLogResponse. The spoken transcript
  /// in, matched catalog meals + grounded estimates out. Slow (one parse call
  /// plus a grounded call per unmatched item), but within the 75s timeout.
  static func voiceLog(transcript: String, lang: String = AppLanguage.current) async throws -> VoiceLogResponse {
    try await APIClient.shared.post("ai/meals/voice-log", body: VoiceLogBody(transcript: transcript, lang: lang))
  }

  /// POST /ai/meals/voice-log/commit (auth) -> VoiceCommitResponse. Persists the
  /// catalog side of a confirmed voice log (new estimated meals + aliases learned
  /// from what the user said). Best-effort — the caller logs the meals regardless.
  @discardableResult
  static func commitVoiceLog(
    newMeals: [VoiceCommitMealInput],
    aliasUpdates: [VoiceAliasUpdate]
  ) async throws -> VoiceCommitResponse {
    try await APIClient.shared.post(
      "ai/meals/voice-log/commit",
      body: VoiceCommitBody(newMeals: newMeals, aliasUpdates: aliasUpdates)
    )
  }

  /// Fire-and-forget warm-up ping — GET /health returns `{ ok: true }` with no
  /// envelope, so we don't decode it. Never throws to the caller.
  static func warmUp() async {
    guard var components = URLComponents(
      url: AppConfig.apiBaseURL.appendingPathComponent("health"),
      resolvingAgainstBaseURL: false
    ) else { return }
    components.queryItems = nil
    guard let url = components.url else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 75
    _ = try? await URLSession.shared.data(for: request)
  }
}
