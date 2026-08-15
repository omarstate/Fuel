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

  /// Manual daily-target override (PUT /profile/targets). The next details
  /// save (PUT /profile) recomputes and overwrites these.
  struct TargetsInput: Codable, Equatable, Sendable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
  }

  static func saveTargets(_ input: TargetsInput) async throws -> Profile {
    try await APIClient.shared.put("profile/targets", body: input)
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
  ///
  /// When the backend can't answer (its shared Render egress IP is often
  /// rate-limited by Open Food Facts), falls back to calling OFF directly from
  /// the device, then best-effort reports the result to the backend so the
  /// shared cache still fills. `.unauthorized` is NOT retried — an expired
  /// session needs a sign-in, and the follow-up log write would fail anyway.
  static func barcodeLookup(code: String) async throws -> BarcodeProduct {
    let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
    do {
      return try await APIClient.shared.get("meals/barcode/\(encoded)")
    } catch let error as APIError where shouldFallBackToDirectLookup(error) {
      let product = try await OpenFoodFactsDirect.lookup(code: code)
      if let name = reportableName(of: product) {
        Task { try? await reportBarcode(product, name: name) }
      }
      return product
    }
  }

  private static func shouldFallBackToDirectLookup(_ error: APIError) -> Bool {
    switch error {
    case .timeout, .network, .decoding: return true
    case let .server(_, status): return status >= 500
    case .unauthorized: return false
    }
  }

  /// Mirrors the backend's barcodeReportSchema bounds so junk OFF data (e.g.
  /// kJ typed into the kcal field) is shown to the scanning user — who can fix
  /// it in review — but never contributed to the shared cache. Returns the
  /// name to report with, or nil when the product shouldn't be reported.
  private static func reportableName(of product: BarcodeProduct) -> String? {
    // Range checks stay in Double space: Int(hugeDouble) traps, and OFF junk
    // data can be arbitrarily large.
    guard product.ok, let name = product.name,
          (1.0...1000.0).contains(product.calories.rounded()),
          product.protein.rounded() <= 100,
          product.carbs.rounded() <= 100,
          product.fat.rounded() <= 100
    else { return nil }
    return name
  }

  private struct BarcodeReportBody: Encodable {
    let name: String
    let brand: String?
    let servingSize: String
    let servingGrams: Double?
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
  }

  private struct BarcodeReportResult: Decodable { let saved: Bool }

  /// POST /meals/barcode/:code (auth). Contributes a successful direct-OFF
  /// lookup to the backend's shared cache. Fire-and-forget.
  @discardableResult
  private static func reportBarcode(_ product: BarcodeProduct, name: String) async throws -> BarcodeReportResult {
    let encoded = product.barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? product.barcode
    let body = BarcodeReportBody(
      name: name,
      brand: product.brand,
      servingSize: product.servingSize,
      servingGrams: product.servingGrams,
      calories: Int(product.calories.rounded()),
      protein: Int(product.protein.rounded()),
      carbs: Int(product.carbs.rounded()),
      fat: Int(product.fat.rounded())
    )
    return try await APIClient.shared.post("meals/barcode/\(encoded)", body: body)
  }

  /// POST /meals/photo-extract (auth) -> ExtractedLabel. `imageBase64` is raw
  /// base64 (no data: prefix). Slow (Gemini vision, 10–40s); a bad photo returns
  /// `readable: false` (soft state), never an error.
  static func extractLabel(imageBase64: String, mimeType: String = "image/jpeg") async throws -> ExtractedLabel {
    try await APIClient.shared.post("meals/photo-extract", body: PhotoExtractBody(image: imageBase64, mimeType: mimeType))
  }

  // MARK: - Workouts (catalog)

  /// GET /workout-categories (public) -> [WorkoutCategory], in sortOrder.
  static func workoutCategories() async throws -> [WorkoutCategory] {
    try await APIClient.shared.get("workout-categories", authorized: false)
  }

  /// GET /workouts/grouped (public) -> every category with its workouts. A
  /// workout in several categories appears under each of them.
  static func workoutsGrouped() async throws -> [GroupedWorkouts] {
    try await APIClient.shared.get("workouts/grouped", authorized: false)
  }

  /// GET /workouts (public) -> { data: [Workout], count }. `category` is a
  /// category SLUG, not an id. Omits empty filters.
  static func workouts(
    category: String?,
    search: String,
    limit: Int,
    offset: Int
  ) async throws -> (items: [Workout], count: Int) {
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
    return try await APIClient.shared.list("workouts", query: query, authorized: false)
  }

  /// GET /workouts/:id (public) -> Workout; 404 if missing.
  static func workout(id: String) async throws -> Workout {
    try await APIClient.shared.get("workouts/\(id)", authorized: false)
  }

  /// POST /workouts -> the created Workout, categories resolved. The route is
  /// open today; we send the bearer token anyway so locking it down later is a
  /// backend-only change.
  static func createWorkout(_ input: WorkoutInput) async throws -> Workout {
    try await APIClient.shared.post("workouts", body: input)
  }

  // MARK: - Voice logging

  /// POST /ai/meals/voice-log (auth) -> VoiceLogResponse. ONE Gemini call parses,
  /// matches against the catalog, and estimates unmatched items — typically 3–6s.
  /// When both recognizers heard something, both readings are sent and the model
  /// decides which is the real speech.
  static func voiceLog(
    transcript: String,
    lang: String = AppLanguage.current,
    readings: [VoiceTranscriptReading] = []
  ) async throws -> VoiceLogResponse {
    try await APIClient.shared.post(
      "ai/meals/voice-log",
      body: VoiceLogBody(transcript: transcript, lang: lang, transcripts: readings.count >= 2 ? readings : nil)
    )
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

  // MARK: - Voice set logging

  /// POST /ai/workouts/voice-log (auth) -> VoiceSetLogResponse. ONE ungrounded
  /// Gemini call — typically 2–4s, unlike the meal voice-log's grounded fan-out,
  /// which is why the flow shows an inline strip instead of a progress screen.
  /// `sessionExercises` are the rows already on screen, so the model can resolve
  /// "كمان سِت" / "same weight" and append instead of inventing a duplicate.
  static func voiceSetLog(
    transcript: String,
    lang: String = AppLanguage.current,
    unit: String = "kg",
    sessionExercises: [VoiceSessionExerciseHint]
  ) async throws -> VoiceSetLogResponse {
    try await APIClient.shared.post(
      "ai/workouts/voice-log",
      body: VoiceSetLogBody(
        transcript: transcript,
        lang: lang,
        unit: unit,
        sessionExercises: sessionExercises
      )
    )
  }

  /// POST /ai/workouts/voice-log/commit (auth) -> VoiceWorkoutCommitResponse.
  /// Teaches the catalog the phrase the user said and saves exercises they chose
  /// to keep. Best-effort — the sets are written to Supabase regardless.
  @discardableResult
  static func commitVoiceSetLog(
    aliasUpdates: [VoiceWorkoutAliasUpdate],
    newWorkouts: [VoiceNewWorkoutInput]
  ) async throws -> VoiceWorkoutCommitResponse {
    try await APIClient.shared.post(
      "ai/workouts/voice-log/commit",
      body: VoiceWorkoutCommitBody(aliasUpdates: aliasUpdates, newWorkouts: newWorkouts)
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
