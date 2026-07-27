import SwiftUI

// Full catalog-meal detail, pushed from the Library list. Renders instantly from
// the list summary while the full detail (creator + community stats) loads, then
// fills in. Shows the calorie split, each macro as a % of the user's daily
// target, the "Fun stats" tiles, provenance, an optional source link, and a
// prominent "Log to today" CTA. Edit/Delete live in the toolbar menu when the
// signed-in user can edit.
struct MealDetailView: View {
  let summary: CatalogMeal
  /// Called after an edit or delete so the Library can invalidate its cache.
  var onChanged: () -> Void = {}
  /// Called after a successful delete so the caller can pop this view.
  var onDeleted: () -> Void = {}

  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  @State private var detail: CatalogMealDetail?
  @State private var overrideMeal: CatalogMeal?
  @State private var isLoading = true
  @State private var error: PresentableError?
  @State private var showEdit = false
  @State private var showLog = false
  @State private var confirmDelete = false
  @State private var deleteTick = 0

  // The freshest meal fields we have: a just-saved edit, else the loaded detail,
  // else the list summary we were pushed with.
  private var meal: CatalogMeal { overrideMeal ?? detail?.meal ?? summary }
  private var canEdit: Bool { meal.canEdit(app.me) }

  private var targets: Targets { app.targets }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        header
        if let error {
          ErrorBanner(error: error, onRetry: { Task { await load() } }, onDismiss: { self.error = nil })
        }
        calorieSplitCard
        nutritionFactsCard
        funStatsSection
        if let url = sourceURL {
          sourceRow(url)
        }
      }
      .padding(20)
    }
    .background(Color.fuelBackground)
    .scrollEdgeEffectStyle(.soft, for: .top)
    .navigationTitle(meal.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if canEdit {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button {
              showEdit = true
            } label: {
              Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
              confirmDelete = true
            } label: {
              Label("Delete", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
          .accessibilityLabel("More")
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      logBar
    }
    .task { await load() }
    .refreshable { await load() }
    .sheet(isPresented: $showEdit) {
      CatalogMealForm(mode: .edit(meal)) { updated in
        overrideMeal = updated
        onChanged()
        Task { await load() }
      }
    }
    .sheet(isPresented: $showLog) {
      AddToLogSheet(meal: meal)
    }
    .confirmationDialog(
      "Delete \(meal.name)?",
      isPresented: $confirmDelete,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        deleteTick += 1
        Task { await deleteMeal() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This removes it from the shared catalog. This can't be undone.")
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: deleteTick)
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        if let category = meal.category {
          PillBadge(title: "\(category.name)", tone: .neutral)
        }
        aiBadge
      }

      Text(meal.name)
        .font(.fuelTitle)
        .foregroundStyle(Color.fuelInk)

      if let serving = meal.servingSize?.trimmingCharacters(in: .whitespaces), !serving.isEmpty {
        Text(serving)
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
      }

      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text("\(Int(meal.calories.rounded()))")
          .font(.fuelStatNumber)
          .foregroundStyle(Color.fuelInk)
          .contentTransition(.numericText())
        Text("kcal")
          .font(.fuelMono(.headline, weight: 500))
          .foregroundStyle(Color.fuelSubtle)
      }

      Text(creatorLine)
        .font(.fuelBody(.footnote))
        .foregroundStyle(Color.fuelSubtle)
        .redacted(reason: detail == nil ? .placeholder : [])

      if let description = meal.description?.trimmingCharacters(in: .whitespaces), !description.isEmpty {
        Text(description)
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelInk.opacity(0.85))
          .padding(.top, 2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var aiBadge: some View {
    switch meal.aiSource {
    case .official:
      PillBadge(title: "Official", systemImage: "checkmark.seal.fill", tone: .volt)
    case .estimate:
      PillBadge(title: "AI estimate", systemImage: "sparkles", tone: .gold)
    case nil:
      EmptyView()
    }
  }

  private var creatorLine: String {
    guard let creator = detail?.creator else {
      return String(localized: "Added by Fuel")
    }
    return creator.system
      ? String(localized: "Added by Fuel")
      : String(localized: "Added by \(creator.name)")
  }

  // MARK: - Calorie split

  private var calorieSplitCard: some View {
    let split = macroSplit
    return VStack(alignment: .leading, spacing: 14) {
      Text("Calorie split").fuelEyebrow()

      GeometryReader { geo in
        HStack(spacing: 0) {
          ForEach(split) { part in
            Capsule(style: .continuous)
              .fill(part.color)
              .frame(width: max(geo.size.width * part.fraction, part.fraction > 0 ? 3 : 0))
          }
        }
      }
      .frame(height: 12)

      HStack(spacing: 16) {
        ForEach(split) { part in
          HStack(spacing: 6) {
            Circle().fill(part.color).frame(width: 9, height: 9)
            Text("\(part.label) \(part.grams)g")
              .font(.fuelMono(.caption))
              .foregroundStyle(Color.fuelSubtle)
            Text("\(part.percent)%")
              .font(.fuelMono(.caption, weight: 600))
              .foregroundStyle(Color.fuelInk)
          }
        }
        Spacer(minLength: 0)
      }
    }
    .cardStyle()
  }

  // MARK: - Nutrition facts

  private var nutritionFactsCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Nutrition facts").fuelEyebrow()
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        fact("Calories", value: Int(meal.calories.rounded()), unit: "kcal",
             pct: percent(Int(meal.calories.rounded()), of: targets.calories), ink: MacroPalette.caloriesInk)
        fact("Protein", value: Int(meal.protein.rounded()), unit: "g",
             pct: percent(Int(meal.protein.rounded()), of: targets.protein), ink: MacroPalette.proteinInk)
        fact("Carbs", value: Int(meal.carbs.rounded()), unit: "g",
             pct: percent(Int(meal.carbs.rounded()), of: targets.carbs), ink: MacroPalette.carbsInk)
        fact("Fat", value: Int(meal.fat.rounded()), unit: "g",
             pct: percent(Int(meal.fat.rounded()), of: targets.fat), ink: MacroPalette.fatInk)
      }
    }
    .cardStyle()
  }

  private func fact(_ label: LocalizedStringKey, value: Int, unit: String, pct: Int, ink: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).fuelEyebrow()
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text("\(value)")
          .font(.fuelMetric)
          .foregroundStyle(ink)
        Text(unit)
          .font(.fuelMono(.caption, weight: 600))
          .foregroundStyle(Color.fuelSubtle)
      }
      Text("\(pct)% of daily goal")
        .font(.fuelMono(.caption2))
        .foregroundStyle(Color.fuelSubtle)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Fun stats

  private var funStatsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Fun stats").fuelEyebrow()

      if let stats = detail?.stats {
        if !hasStats(stats) {
          Text("Nobody's logged this yet — be the first.")
            .font(.fuelBody(.subheadline))
            .foregroundStyle(Color.fuelSubtle)
        }
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          StatTile(label: "Logged today", value: stats.loggedToday.formatted(), systemImage: "flame.fill", tint: .fuelVoltInk)
          StatTile(label: "All-time logs", value: stats.loggedTotal.formatted(), systemImage: "arrow.triangle.2.circlepath", tint: .fuelCitrusInk)
          StatTile(label: "People logging it", value: stats.uniqueLoggers.formatted(), systemImage: "person.2.fill", tint: .fuelGoldInk)
          StatTile(label: "Last logged", value: lastLoggedText(stats.lastLoggedAt), systemImage: "clock.fill", tint: .fuelSubtle)
          StatTile(label: "Protein density", value: proteinDensity.formatted(), unit: "g/100kcal", systemImage: "gauge.medium", tint: .fuelVoltInk)
        }
      } else {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          ForEach(0..<4, id: \.self) { _ in
            StatTile(label: "Loading", value: "—")
          }
        }
        .redacted(reason: .placeholder)
      }
    }
  }

  private func hasStats(_ stats: CatalogMealDetail.Stats) -> Bool {
    stats.loggedToday > 0 || stats.loggedTotal > 0 || stats.uniqueLoggers > 0
  }

  private func lastLoggedText(_ date: Date?) -> String {
    guard let date else { return String(localized: "Never") }
    return date.formatted(.relative(presentation: .named))
  }

  private var proteinDensity: Int {
    let kcal = max(meal.calories, 1)
    return Int((meal.protein / kcal * 100).rounded())
  }

  // MARK: - Source

  private var sourceURL: URL? {
    guard let raw = meal.sourceUrl, let url = URL(string: raw) else { return nil }
    return url
  }

  private func sourceRow(_ url: URL) -> some View {
    Button {
      openURL(url)
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "link")
        Text("View source")
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(.footnote.weight(.semibold))
          .flipsForRightToLeftLayoutDirection(true)
      }
      .font(.fuelBody(.subheadline, weight: 500))
      .foregroundStyle(Color.fuelCitrusInk)
      .cardStyle()
    }
    .buttonStyle(.plain)
  }

  // MARK: - Log CTA

  private var logBar: some View {
    Button {
      showLog = true
    } label: {
      Label("Log to today", systemImage: "plus")
        .font(.fuelBody(.headline, weight: 600))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
    .buttonStyle(.glassProminent)
    .tint(.fuelCitrus)
    .padding(.horizontal, 20)
    .padding(.bottom, 6)
  }

  // MARK: - Helpers

  private func percent(_ value: Int, of goal: Int) -> Int {
    guard goal > 0 else { return 0 }
    return Int((Double(value) / Double(goal) * 100).rounded())
  }

  private struct MacroPart: Identifiable {
    let id: String
    let label: String
    let grams: Int
    let kcal: Double
    let color: Color
    var fraction: Double
    var percent: Int
  }

  private var macroSplit: [MacroPart] {
    let parts: [(String, Double, Double, Color)] = [
      ("Protein", meal.protein, 4, MacroPalette.proteinFill),
      ("Carbs", meal.carbs, 4, MacroPalette.carbsFill),
      ("Fat", meal.fat, 9, MacroPalette.fatFill),
    ]
    let kcals = parts.map { $0.1 * $0.2 }
    let sum = kcals.reduce(0, +)
    let base = sum > 0 ? sum : max(meal.calories, 1)
    return zip(parts, kcals).map { part, kcal in
      MacroPart(
        id: part.0,
        label: part.0,
        grams: Int(part.1.rounded()),
        kcal: kcal,
        color: part.3,
        fraction: kcal / base,
        percent: Int((kcal / base * 100).rounded())
      )
    }
  }

  // MARK: - Actions

  private func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      detail = try await FuelAPI.mealDetail(id: summary.id)
      error = nil
    } catch {
      self.error = PresentableError(error)
    }
  }

  private func deleteMeal() async {
    do {
      try await FuelAPI.deleteMeal(id: meal.id)
      onChanged()
      onDeleted()
      dismiss()
    } catch {
      self.error = PresentableError(error)
    }
  }
}

private extension View {
  func cardStyle() -> some View {
    self
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .fuelCard()
  }
}
