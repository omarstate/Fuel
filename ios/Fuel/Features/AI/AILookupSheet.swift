import SwiftUI

// AI meal lookup: type a dish, the backend checks the catalog then does a
// grounded web search, and we show result cards to log. Presented from the Today
// toolbar and a Library toolbar button. Slow (10–30s) → rotating hint lines and
// a skeleton while searching. A stale-response guard drops results from a query
// the user has since replaced.
struct AILookupSheet: View {
  @Environment(\.dismiss) private var dismiss

  @State private var query = ""
  @State private var phase: Phase = .idle
  @State private var searchToken = 0
  @State private var logTarget: CatalogMeal?
  @FocusState private var searchFocused: Bool

  private enum Phase: Equatable {
    case idle
    case searching
    case results([AiLookupItem])
    case empty
    case failed(PresentableError)
  }

  private let hints: [LocalizedStringKey] = [
    "Searching the web…",
    "Reading nutrition data…",
    "Checking the catalog…",
    "Crunching the macros…",
  ]

  private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var canSearch: Bool { trimmedQuery.count >= 2 && phase != .searching }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          searchField
          content
        }
        .padding(20)
      }
      .background(Color.fuelBackground)
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("AI Lookup")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .sheet(item: $logTarget) { meal in
      AddToLogSheet(meal: meal)
    }
    .onDisappear { searchToken += 1 } // ignore any in-flight result
    .task { searchFocused = true }
  }

  // MARK: - Search field

  private var searchField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Find a meal").fuelEyebrow()
      HStack(spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(Color.fuelSubtle)
          TextField("e.g. koshari, Big Mac, molokhia", text: $query)
            .focused($searchFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .onSubmit { runSearch() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.fuelSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        Button {
          runSearch()
        } label: {
          Image(systemName: "sparkles")
            .font(.body.weight(.semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.glassProminent)
        .tint(.fuelCitrus)
        .disabled(!canSearch)
        .accessibilityLabel("Look up")
      }
      Text("Searches the Egypt-first catalog, then the web.")
        .font(.fuelBody(.caption))
        .foregroundStyle(Color.fuelSubtle)
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    switch phase {
    case .idle:
      idleState
    case .searching:
      AIProgressView(hints: hints, title: "Looking that up…")
    case let .results(items):
      VStack(spacing: 12) {
        ForEach(items) { item in
          ResultCard(item: item) { logTarget = item.meal }
        }
      }
    case .empty:
      ContentUnavailableView {
        Label("No matches", systemImage: "questionmark.circle")
      } description: {
        Text("Try a different or more specific name.")
      }
      .padding(.top, 12)
    case let .failed(error):
      ErrorBanner(error: error, onRetry: { runSearch() }, onDismiss: { phase = .idle })
    }
  }

  private var idleState: some View {
    VStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 34))
        .foregroundStyle(Color.fuelVoltInk)
      Text("Look up any meal")
        .font(.fuelHeading(.headline))
        .foregroundStyle(Color.fuelInk)
      Text("Type what you ate and we'll pull the nutrition — official data where it exists, an AI estimate otherwise.")
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 24)
  }

  // MARK: - Search

  private func runSearch() {
    let q = trimmedQuery
    guard q.count >= 2, phase != .searching else { return }
    searchFocused = false
    searchToken += 1
    let token = searchToken
    phase = .searching
    Task {
      do {
        let response = try await FuelAPI.lookupMeals(query: q)
        guard token == searchToken else { return }
        phase = response.items.isEmpty ? .empty : .results(response.items)
      } catch {
        guard token == searchToken else { return }
        phase = .failed(PresentableError(error))
      }
    }
  }
}

// MARK: - Result card

private struct ResultCard: View {
  let item: AiLookupItem
  var onLog: () -> Void

  @Environment(\.openURL) private var openURL

  private var meal: CatalogMeal { item.meal }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(meal.name)
            .font(.fuelHeading(.headline))
            .foregroundStyle(Color.fuelInk)
          HStack(spacing: 6) {
            sourceBadge
            if let serving = meal.servingSize?.trimmingCharacters(in: .whitespaces), !serving.isEmpty {
              Text(serving)
                .font(.fuelBody(.caption))
                .foregroundStyle(Color.fuelSubtle)
            }
          }
          if !item.created {
            Text("Already in your library")
              .font(.fuelBody(.caption2))
              .foregroundStyle(Color.fuelSubtle)
          }
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 1) {
          Text(kcalLabel)
            .font(.fuelMono(.headline, weight: 600))
            .foregroundStyle(Color.fuelInk)
          Text("kcal").fuelEyebrow()
        }
      }

      HStack {
        HStack(spacing: 12) {
          macro("P", Int(meal.protein.rounded()), MacroPalette.proteinInk)
          macro("C", Int(meal.carbs.rounded()), MacroPalette.carbsInk)
          macro("F", Int(meal.fat.rounded()), MacroPalette.fatInk)
        }
        Spacer()
        Button(action: onLog) {
          Label("Log", systemImage: "plus")
            .font(.fuelBody(.subheadline, weight: 600))
        }
        .buttonStyle(.glass)
        .tint(.fuelCitrus)
      }

      if let host = sourceHost, let url = sourceURL {
        Button {
          openURL(url)
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "link")
            Text(host)
            Image(systemName: "arrow.up.right")
              .flipsForRightToLeftLayoutDirection(true)
          }
          .font(.fuelBody(.caption))
          .foregroundStyle(Color.fuelSubtle)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fuelCard()
  }

  @ViewBuilder
  private var sourceBadge: some View {
    switch meal.aiSource {
    case .official:
      PillBadge(title: "Official", systemImage: "checkmark.seal.fill", tone: .volt)
    case .estimate:
      PillBadge(title: "AI estimate", systemImage: "sparkles", tone: .gold)
    case nil:
      EmptyView()
    }
  }

  // Estimates carry a min–max calorie range; officials show a single number.
  private var kcalLabel: String {
    if meal.aiSource == .estimate, let range = meal.macroRanges?.calories {
      return "\(Int(range.min.rounded()))–\(Int(range.max.rounded()))"
    }
    return "\(Int(meal.calories.rounded()))"
  }

  private var sourceURL: URL? {
    guard let raw = meal.sourceUrl, let url = URL(string: raw) else { return nil }
    return url
  }

  private var sourceHost: String? {
    guard let host = sourceURL?.host() else { return nil }
    return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
  }

  private func macro(_ letter: String, _ grams: Int, _ ink: Color) -> some View {
    HStack(spacing: 2) {
      Text(letter).font(.fuelMono(.caption, weight: 700)).foregroundStyle(ink)
      Text("\(grams)g").font(.fuelMono(.caption)).foregroundStyle(Color.fuelSubtle)
    }
  }
}

#Preview {
  AILookupSheet()
    .environment(AppState())
}
