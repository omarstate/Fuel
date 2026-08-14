import SwiftUI

// Voice meal logging — the fastest way to log. The sheet opens SMALL and already
// listening: say what you ate in Egyptian Arabic or English ("أكلت تلات بيضات
// مسلوقين وتوستتين، ضيفهم على الفطار"), watch the wave move, hit Confirm. One
// backend call parses the items, matches them against the catalog, and estimates
// whatever it doesn't recognise; the sheet then grows to full height for the
// review step, which stays mandatory.
//
// Language is DETECTED, not chosen (SpeechRecorder races an Arabic and an
// English recognizer over the same audio) — people mix the two mid-sentence, and
// a picker taxed every log to save an occasional mis-hearing.
//
// The transcript stays EDITABLE, so a denied mic or missing speech assets
// degrades into a plain typed path instead of a dead end. On confirm the catalog
// side is committed best-effort (new meals + the phrase the user actually said,
// learned as an alias) and the log rows are written straight to Supabase under
// RLS, one independent insert each.
struct VoiceLogFlow: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var app

  @State private var recorder = SpeechRecorder()
  @State private var step: Step = .capture
  @State private var analyzing = false
  @State private var rows: [VoiceRow] = []
  @State private var mealType: MealType = MealTypeSuggestion.suggested()
  /// Set only when the user actually named a section out loud.
  @State private var spokenMealType: MealType?
  @State private var error: PresentableError?
  /// The mic starts itself exactly once — coming "Back" from review must not
  /// seize the mic again behind the user.
  @State private var didAutoStart = false
  /// Capture is a mini modal; only the review step earns the full sheet.
  @State private var detent: PresentationDetent = .height(320)
  @FocusState private var keyboardActive: Bool

  private let repo = MealLogRepository()
  private let suggested = MealTypeSuggestion.suggested()

  private enum Step { case capture, review }

  private var trimmedTranscript: String {
    recorder.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Confirm is live WHILE recording — it stops the mic itself. Requiring a stop
  /// first would put a second tap between the user and the only action here.
  private var canAnalyze: Bool {
    !analyzing && trimmedTranscript.count >= 2
  }

  private var usableCount: Int { rows.filter(\.isUsable).count }

  /// The placeholder utterance, in the app's language. The recorder no longer
  /// has a chosen language to ask.
  private var example: String {
    VoiceLanguage.appDefault.example(for: .meal)
  }

  var body: some View {
    NavigationStack {
      Group {
        if analyzing {
          analyzingState
        } else {
          switch step {
          case .capture: captureStep
          case .review: reviewForm
          }
        }
      }
      .background(Color.fuelBackground)
      .navigationTitle(step == .capture ? "Log by voice" : "Review what you said")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent }
    }
    .presentationDetents([.height(320), .large], selection: $detent)
    .presentationDragIndicator(.visible)
    .interactiveDismissDisabled(analyzing)
    .task {
      guard !didAutoStart else { return }
      didAutoStart = true
      await recorder.start()
    }
    .onChange(of: step) { _, newStep in
      // The review step is a full form; capture is the mini modal it came from.
      withAnimation(.snappy) {
        detent = newStep == .review ? .large : .height(320)
      }
    }
    .onDisappear { recorder.stop() }
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    if step == .capture {
      // Capture has ONE action and it lives on the Confirm button under the
      // wave, so the toolbar keeps only the way out.
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") { dismiss() }
          .disabled(analyzing)
      }
    } else {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          step = .capture
        } label: {
          Label("Back", systemImage: "chevron.backward")
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        AsyncButton(logLabel, style: .glassProminent, tint: .fuelCitrus, successHaptic: true) {
          try await logAll()
        } onError: { err in
          error = PresentableError(err)
        }
        .disabled(usableCount == 0)
      }
    }
  }

  private var logLabel: LocalizedStringKey {
    usableCount <= 1 ? "Log item" : "Log \(usableCount) items"
  }

  // MARK: - Capture step

  private var captureStep: some View {
    VStack(spacing: 10) {
      if let error {
        ErrorBanner(error: error, onDismiss: { self.error = nil })
          .padding(.horizontal, 20)
          .padding(.top, 8)
      }
      VoiceCaptureView(
        recorder: recorder,
        accent: .fuelCitrus,
        accentInk: .fuelCitrusInk,
        example: example,
        isAnalyzing: analyzing,
        canConfirm: canAnalyze,
        onConfirm: confirm
      )
    }
  }

  /// The mini modal's one action: stop listening, then analyze. Errors surface
  /// in the banner above the wave rather than throwing out of the button.
  private func confirm() async {
    await recorder.finish()
    do {
      try await analyze()
    } catch {
      self.error = PresentableError(error)
    }
  }

  // MARK: - Analyzing state

  private var analyzingState: some View {
    AIProgressView(hints: analyzeHints, title: "Working out what you ate…")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var analyzeHints: [LocalizedStringKey] {
    [
      "Reading what you said…",
      "Matching against your library…",
      "Checking Egyptian portions first…",
      "Crunching the macros…",
    ]
  }

  // MARK: - Review step

  private var reviewForm: some View {
    Form {
      Section {
        Picker("Section", selection: $mealType) {
          ForEach(MealTypeSuggestion.order) { type in
            Text(type == suggested ? "\(type.label) · \(String(localized: "Suggested"))" : type.label).tag(type)
          }
        }
        .pickerStyle(.menu)
        .tint(.fuelCitrusInk)
      } header: {
        Text("Section")
      } footer: {
        Text(sectionFooter)
      }

      ForEach($rows) { $row in
        reviewSection($row)
      }

      if let error {
        Section {
          ErrorBanner(error: error, onDismiss: { self.error = nil })
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { keyboardActive = false }
      }
    }
  }

  private var sectionFooter: LocalizedStringKey {
    spokenMealType == nil
      ? "Picked from the time of day — change it if you like."
      : "You said this one goes to \(mealType.label)."
  }

  @ViewBuilder
  private func reviewSection(_ row: Binding<VoiceRow>) -> some View {
    Section {
      if let meal = row.wrappedValue.meal {
        catalogBody(row, meal: meal)
      } else if row.wrappedValue.ok {
        estimateBody(row)
      } else {
        manualBody(row)
      }
    } header: {
      HStack(spacing: 6) {
        badge(row.wrappedValue)
        Spacer()
        Button(role: .destructive) {
          withAnimation(.snappy) { rows.removeAll { $0.id == row.wrappedValue.id } }
        } label: {
          Image(systemName: "trash")
            .font(.caption.weight(.semibold))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.fuelDestructive)
        .textCase(nil)
        .accessibilityLabel("Remove item")
      }
    } footer: {
      footer(for: row.wrappedValue)
    }
  }

  @ViewBuilder
  private func badge(_ row: VoiceRow) -> some View {
    if row.meal != nil {
      PillBadge(title: "In your library", systemImage: "books.vertical.fill", tone: .citrus)
    } else if row.ok {
      PillBadge(title: "AI estimate", systemImage: "sparkles", tone: confidenceTone(row.confidence))
    } else {
      PillBadge(title: "Needs your numbers", tone: .neutral)
    }
  }

  private func confidenceTone(_ confidence: VoiceConfidence?) -> PillBadge.Tone {
    switch confidence {
    case .high: return .volt
    case .medium: return .gold
    case .low, nil: return .neutral
    }
  }

  // A catalog match: name, the words that matched it, a serving multiplier and
  // the live scaled macros.
  @ViewBuilder
  private func catalogBody(_ row: Binding<VoiceRow>, meal: CatalogMeal) -> some View {
    nameHeader(name: meal.name, spoken: row.wrappedValue.spoken)
    portionStepper(row)
    macroPreview(row.wrappedValue.scaled)
  }

  // An estimate we trust: per-base-serving macros ("1 slice") with the same
  // servings stepper as a catalog match, seeded from the quantity spoken.
  @ViewBuilder
  private func estimateBody(_ row: Binding<VoiceRow>) -> some View {
    nameHeader(
      name: row.wrappedValue.name,
      spoken: row.wrappedValue.spoken,
      detail: row.wrappedValue.servingSize
    )
    portionStepper(row)
    macroPreview(row.wrappedValue.scaled)
  }

  // A soft failure: the user fills it in by hand and it becomes loggable.
  @ViewBuilder
  private func manualBody(_ row: Binding<VoiceRow>) -> some View {
    TextField("Item name", text: row.name)
      .font(.fuelBody(.body, weight: 500))
      .foregroundStyle(Color.fuelInk)
      .focused($keyboardActive)
    TextField("Serving size (optional)", text: row.servingSize)
      .font(.fuelBody(.subheadline))
      .focused($keyboardActive)
    macroField("Calories", text: row.calories, unit: "kcal", ink: MacroPalette.caloriesInk)
    macroField("Protein", text: row.protein, unit: "g", ink: MacroPalette.proteinInk)
    macroField("Carbs", text: row.carbs, unit: "g", ink: MacroPalette.carbsInk)
    macroField("Fat", text: row.fat, unit: "g", ink: MacroPalette.fatInk)
  }

  @ViewBuilder
  private func nameHeader(name: String, spoken: String, detail: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(name)
        .font(.fuelBody(.body, weight: 500))
        .foregroundStyle(Color.fuelInk)
      if let detail, !detail.trimmingCharacters(in: .whitespaces).isEmpty {
        Text(detail)
          .font(.fuelBody(.footnote))
          .foregroundStyle(Color.fuelSubtle)
      }
      if !VoiceAliases.sameText(spoken, name), !spoken.isEmpty {
        Text("You said “\(spoken)”")
          .font(.fuelBody(.caption))
          .foregroundStyle(Color.fuelSubtle)
      }
    }
  }

  private func portionStepper(_ row: Binding<VoiceRow>) -> some View {
    HStack {
      Text("Servings").foregroundStyle(Color.fuelInk)
      Spacer()
      HStack(spacing: 14) {
        stepButton("minus", disabled: row.wrappedValue.factor <= VoiceRow.minFactor) {
          row.wrappedValue.factor = max(VoiceRow.minFactor, row.wrappedValue.factor - VoiceRow.factorStep)
        }
        Text("\(PortionScaling.factorLabel(row.wrappedValue.factor))×")
          .font(.fuelMono(.body, weight: 600))
          .foregroundStyle(Color.fuelInk)
          .frame(minWidth: 48)
          .contentTransition(.numericText())
        stepButton("plus", disabled: row.wrappedValue.factor >= VoiceRow.maxFactor) {
          row.wrappedValue.factor = min(VoiceRow.maxFactor, row.wrappedValue.factor + VoiceRow.factorStep)
        }
      }
    }
  }

  private func stepButton(_ systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(.snappy) { action() }
    } label: {
      Image(systemName: systemName)
        .font(.body.weight(.bold))
        .frame(width: 30, height: 30)
    }
    .buttonStyle(.bordered)
    .buttonBorderShape(.circle)
    .tint(.fuelCitrus)
    .disabled(disabled)
    .accessibilityLabel(systemName == "minus" ? "Fewer servings" : "More servings")
  }

  private func macroPreview(_ macros: PortionScaling.Macros) -> some View {
    HStack(spacing: 5) {
      Text("\(macros.calories)").foregroundStyle(Color.fuelInk)
      Text("kcal").foregroundStyle(Color.fuelSubtle)
      Text("·").foregroundStyle(Color.fuelSubtle)
      Text("\(macros.protein)P").foregroundStyle(MacroPalette.proteinInk)
      Text("\(macros.carbs)C").foregroundStyle(MacroPalette.carbsInk)
      Text("\(macros.fat)F").foregroundStyle(MacroPalette.fatInk)
    }
    .font(.fuelMono(.subheadline, weight: 600))
    .contentTransition(.numericText())
    .environment(\.layoutDirection, .leftToRight)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func macroField(_ label: LocalizedStringKey, text: Binding<String>, unit: String, ink: Color) -> some View {
    HStack {
      Text(label).foregroundStyle(Color.fuelInk)
      Spacer()
      TextField("0", text: text)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .font(.fuelMono(.body))
        .focused($keyboardActive)
        .frame(maxWidth: 90)
      Text(unit)
        .font(.fuelMono(.footnote, weight: 600))
        .foregroundStyle(ink)
        .frame(width: 34, alignment: .leading)
    }
  }

  @ViewBuilder
  private func footer(for row: VoiceRow) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      if let meal = row.meal {
        if let serving = VoiceAliases.annotatedServingSize(factor: row.factor, base: meal.servingSize) {
          Text(serving)
            .font(.fuelMono(.caption))
            .foregroundStyle(Color.fuelSubtle)
        }
      } else if row.ok, row.factor != 1,
                let serving = VoiceAliases.annotatedServingSize(factor: row.factor, base: row.servingSize) {
        Text(serving)
          .font(.fuelMono(.caption))
          .foregroundStyle(Color.fuelSubtle)
      } else if !row.ok {
        Text("Couldn't estimate this one — add a name and calories to include it.")
          .foregroundStyle(Color.fuelCitrusInk)
      }

      if row.ok, let ranges = row.ranges {
        Text(rangeSummary(ranges, factor: row.factor))
          .font(.fuelMono(.caption))
          .foregroundStyle(Color.fuelSubtle)
          .environment(\.layoutDirection, .leftToRight)
      }

      if row.ok, !row.note.trimmingCharacters(in: .whitespaces).isEmpty {
        Text(row.note)
          .foregroundStyle(Color.fuelSubtle)
      }

      if let host = row.sourceHost {
        Text("Source: \(host)")
          .foregroundStyle(Color.fuelSubtle)
      }
    }
  }

  // "220–260 kcal · P 17–21 · C 1–3 · F 14–18" — an estimate's plausible band.
  // Ranges band the BASE serving, so they scale by the row's multiplier to stay
  // consistent with the macros shown next to them.
  private func rangeSummary(_ ranges: CatalogMeal.MacroRanges, factor: Double) -> String {
    func part(_ range: CatalogMeal.MacroRange) -> String {
      "\(Int((range.min * factor).rounded()))–\(Int((range.max * factor).rounded()))"
    }
    return "\(part(ranges.calories)) kcal · P \(part(ranges.protein)) · C \(part(ranges.carbs)) · F \(part(ranges.fat))"
  }

  // MARK: - Actions

  private func analyze() async throws {
    recorder.stop()
    keyboardActive = false
    // What the recognizers decided was actually spoken. Purely typed input never
    // sets it, so the app's own language is the fallback.
    let lang = recorder.detectedLanguage?.apiLang ?? VoiceLanguage.appDefault.apiLang
    let transcript = trimmedTranscript
    guard transcript.count >= 2 else {
      throw APIError.server(message: String(localized: "Say or type what you ate first."), status: 400)
    }

    // Both recognizers transcribed the same audio, and picking a winner locally
    // is a guess — when we still have both readings intact, send them and let the
    // model judge which is real speech. A transcript the user typed over is their
    // words, not a recognizer's, so that path sends only what's in the field.
    let readings = recorder.transcriptWasEdited
      ? []
      : recorder.candidateTranscripts.map { VoiceTranscriptReading(lang: $0.language.apiLang, text: $0.text) }

    error = nil
    analyzing = true
    defer { analyzing = false }

    let response = readings.count >= 2
      ? try await FuelAPI.voiceLog(transcript: transcript, lang: lang, readings: readings)
      : try await FuelAPI.voiceLog(transcript: transcript, lang: lang)
    let parsed = response.items.map(VoiceRow.init(item:))
    guard !parsed.isEmpty else {
      throw APIError.server(
        message: String(localized: "Couldn't find any food in that. Try saying what you ate again."),
        status: 400
      )
    }

    rows = parsed
    spokenMealType = response.mealType
    mealType = response.mealType ?? MealTypeSuggestion.suggested()
    step = .review
  }

  private func logAll() async throws {
    let kept = rows.filter(\.isUsable)
    guard !kept.isEmpty else {
      throw APIError.server(message: String(localized: "Add a name and calories to at least one item."), status: 400)
    }

    // 1. Teach the catalog what it learned from this utterance — new estimated
    //    meals, and the spoken phrase as an alias on the meals that matched.
    //    Entirely best-effort: catalog learning must NEVER block logging.
    var createdIds: [String: String] = [:]
    let newMeals = kept.compactMap { $0.commitInput() }
    let aliasUpdates = kept.compactMap { $0.aliasUpdate() }
    if !newMeals.isEmpty || !aliasUpdates.isEmpty,
       let response = try? await FuelAPI.commitVoiceLog(newMeals: newMeals, aliasUpdates: aliasUpdates) {
      for created in response.meals {
        createdIds[created.name.lowercased()] = created.meal.id
      }
    }

    // 2. The personal log is written directly to Supabase under RLS, never
    //    through the API. Independent inserts so one failure keeps the rest.
    let userID = try await repo.userID()
    let now = Date()
    var saved = 0
    for row in kept {
      let catalogId = row.meal?.id ?? createdIds[row.trimmedName.lowercased()]
      guard let entry = row.loggedMeal(
        userId: userID,
        mealType: mealType,
        loggedAt: now,
        catalogMealId: catalogId.flatMap(UUID.init(uuidString:))
      ) else { continue }
      do {
        try await repo.insert(entry)
        saved += 1
      } catch {
        // keep going; surfaced below if nothing landed
      }
    }

    guard saved > 0 else {
      throw APIError.server(message: String(localized: "Couldn't log those items. Try again."), status: 500)
    }

    app.bumpLogRevision()
    dismiss()
  }
}

// MARK: - Review row

// One editable review row. Catalog matches carry the meal plus a serving
// multiplier (macros scale live); estimates carry their own macros as strings so
// the decimal-pad fields stay controlled while a soft failure is filled in by
// hand — the same shape as EstimateRow in the AI estimate flow.
private struct VoiceRow: Identifiable, Equatable {
  static let minFactor: Double = 0.25
  static let maxFactor: Double = 10
  static let factorStep: Double = 0.25

  let id = UUID()
  let spoken: String
  /// Non-nil when the model matched a meal already in the catalog.
  let meal: CatalogMeal?
  var factor: Double
  var name: String
  var servingSize: String
  var calories: String
  var protein: String
  var carbs: String
  var fat: String
  let ranges: CatalogMeal.MacroRanges?
  let sourceUrl: String?
  let confidence: VoiceConfidence?
  let note: String
  let ok: Bool

  init(item: VoiceLogItem) {
    switch item {
    case .catalog(let match):
      spoken = match.spoken
      meal = match.meal
      factor = Self.snapped(match.factor)
      name = match.meal.name
      servingSize = match.meal.servingSize ?? ""
      calories = Self.intString(match.meal.calories)
      protein = Self.intString(match.meal.protein)
      carbs = Self.intString(match.meal.carbs)
      fat = Self.intString(match.meal.fat)
      ranges = nil
      sourceUrl = match.meal.sourceUrl
      confidence = nil
      note = ""
      ok = true
    case .estimate(let estimate):
      spoken = estimate.spoken
      meal = nil
      factor = Self.snapped(estimate.factor)
      name = estimate.name.isEmpty ? estimate.spoken : estimate.name
      servingSize = estimate.servingSize
      calories = Self.intString(estimate.calories)
      protein = Self.intString(estimate.protein)
      carbs = Self.intString(estimate.carbs)
      fat = Self.intString(estimate.fat)
      ranges = estimate.ranges
      sourceUrl = estimate.sourceUrl
      confidence = estimate.confidence
      note = estimate.note
      ok = estimate.ok
    }
  }

  private static func intString(_ value: Double) -> String {
    String(Int(value.rounded()))
  }

  /// Snap the model's factor onto the stepper's grid so the control and the
  /// macros agree from the first frame.
  static func snapped(_ factor: Double) -> Double {
    let stepped = (factor / factorStep).rounded() * factorStep
    return min(max(stepped, minFactor), maxFactor)
  }

  var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var caloriesValue: Int { NumberParsing.int(calories) ?? 0 }
  private var proteinValue: Int { NumberParsing.int(protein) ?? 0 }
  private var carbsValue: Int { NumberParsing.int(carbs) ?? 0 }
  private var fatValue: Int { NumberParsing.int(fat) ?? 0 }

  /// Catalog AND estimate macros are per one base serving and scale by the
  /// multiplier. Manual rows keep factor 1, so what's typed is what's logged.
  var scaled: PortionScaling.Macros {
    if let meal {
      return PortionScaling.macros(
        calories: meal.calories,
        protein: meal.protein,
        carbs: meal.carbs,
        fat: meal.fat,
        factor: factor
      )
    }
    return PortionScaling.macros(
      calories: Double(max(caloriesValue, 0)),
      protein: Double(max(proteinValue, 0)),
      carbs: Double(max(carbsValue, 0)),
      fat: Double(max(fatValue, 0)),
      factor: factor
    )
  }

  /// Loggable: a catalog match or a trusted estimate always is; a soft failure
  /// becomes loggable once it has a name and some calories.
  var isUsable: Bool {
    meal != nil || ok || (!trimmedName.isEmpty && caloriesValue > 0)
  }

  var sourceHost: String? {
    guard let sourceUrl, let host = URL(string: sourceUrl)?.host() else { return nil }
    return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
  }

  private var loggedName: String {
    trimmedName.isEmpty ? spoken : trimmedName
  }

  private var loggedServingSize: String? {
    if let meal {
      return VoiceAliases.annotatedServingSize(factor: factor, base: meal.servingSize)
    }
    if ok {
      // Estimates are per base serving too — "3× 1 slice (~25g)".
      return VoiceAliases.annotatedServingSize(factor: factor, base: servingSize)
    }
    let trimmed = servingSize.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  func loggedMeal(userId: UUID, mealType: MealType, loggedAt: Date, catalogMealId: UUID?) -> LoggedMeal? {
    guard isUsable else { return nil }
    let macros = scaled
    return LoggedMeal(
      userId: userId,
      name: loggedName,
      mealType: mealType,
      servingSize: loggedServingSize,
      calories: macros.calories,
      protein: macros.protein,
      carbs: macros.carbs,
      fat: macros.fat,
      loggedAt: loggedAt,
      catalogMealId: catalogMealId
    )
  }

  /// A confirmed estimate worth saving to the shared catalog, with the spoken
  /// phrase attached as an alias so the next utterance matches it directly.
  /// Saves the UNSCALED base serving ("Toast — 1 slice, 70 kcal"), never the
  /// spoken total, so the catalog entry stays reusable at any quantity.
  func commitInput() -> VoiceCommitMealInput? {
    guard meal == nil, ok, !trimmedName.isEmpty else { return nil }
    let serving = servingSize.trimmingCharacters(in: .whitespacesAndNewlines)
    return VoiceCommitMealInput(
      name: trimmedName,
      servingSize: serving.isEmpty ? String(localized: "1 serving") : serving,
      calories: max(caloriesValue, 0),
      protein: max(proteinValue, 0),
      carbs: max(carbsValue, 0),
      fat: max(fatValue, 0),
      sourceUrl: sourceUrl,
      ranges: ranges,
      aliases: VoiceAliases.deriveAliases(spoken: spoken, name: trimmedName)
    )
  }

  /// The phrase to teach a matched catalog meal. Skipped when the id isn't a
  /// UUID (previews/fixtures) so a rejected body can't take the commit down.
  func aliasUpdate() -> VoiceAliasUpdate? {
    guard let meal, UUID(uuidString: meal.id) != nil else { return nil }
    let aliases = VoiceAliases.deriveAliases(spoken: spoken, name: meal.name)
    guard !aliases.isEmpty else { return nil }
    return VoiceAliasUpdate(catalogMealId: meal.id, aliases: aliases)
  }
}

#Preview {
  VoiceLogFlow()
    .environment(AppState())
}
