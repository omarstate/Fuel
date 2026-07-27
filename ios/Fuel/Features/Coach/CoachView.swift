import SwiftUI

// The Coach tab: a daily AI narrative (insights + tips + streak) and a
// deterministic "up next" section suggesting library meals that fit what's left
// of today's macros. Editorial layout — Google Sans Flex masthead, content on FuelSurface,
// never glass. Slow first load gets the cold-start treatment; unconfigured /
// rate-limited AI collapses each section into a quiet card.
struct CoachView: View {
  @Environment(AppState.self) private var app
  @State private var model = CoachViewModel()
  @State private var logTarget: CatalogMeal?
  @State private var refreshingSuggestions = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          InsightsSection(
            state: model.insights,
            onRetry: { Task { await model.loadInsights(refresh: false) } }
          )
          SuggestionsSection(
            state: model.suggestions,
            remaining: model.remaining,
            refreshing: refreshingSuggestions,
            onRefresh: refreshSuggestions,
            onRetry: { Task { await model.loadSuggestions(refresh: false) } },
            onLog: { logTarget = $0 }
          )
        }
        .padding(20)
      }
      .background(Color.fuelBackground)
      .scrollEdgeEffectStyle(.soft, for: .top)
      .navigationTitle("Coach")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Task { await model.refreshAll() }
          } label: {
            Image(systemName: "arrow.clockwise")
              .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
              .animation(model.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isRefreshing)
          }
          .disabled(model.isRefreshing)
          .accessibilityLabel("Refresh coach")
        }
      }
      .coldStart(isLoading: model.isFirstLoading)
    }
    .task { await model.load(targets: app.targets) }
    .onChange(of: app.targets) { model.updateTargets(app.targets) }
    .onChange(of: app.logRevision) { Task { await model.reloadSuggestionsForNewLog() } }
    .sheet(item: $logTarget) { AddToLogSheet(meal: $0) }
  }

  private func refreshSuggestions() {
    guard !refreshingSuggestions else { return }
    refreshingSuggestions = true
    Task {
      await model.loadSuggestions(refresh: true)
      refreshingSuggestions = false
    }
  }
}

// MARK: - Insights

private struct InsightsSection: View {
  let state: CoachViewModel.SectionState<AiInsights>
  var onRetry: () -> Void

  var body: some View {
    switch state {
    case .loading:
      InsightsSkeleton()
    case .unavailable:
      UnavailableCard(
        eyebrow: "Coach",
        message: "Coach is warming up — check back soon."
      )
    case let .failed(error):
      SectionErrorCard(eyebrow: "Coach", error: error, onRetry: onRetry)
    case let .ready(data):
      InsightsContent(data: data)
    }
  }
}

private struct InsightsContent: View {
  let data: AiInsights

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Coach").fuelEyebrow()
        Text(data.headline)
          .font(.fuelTitle2)
          .foregroundStyle(Color.fuelInk)
          .fixedSize(horizontal: false, vertical: true)
      }

      if let streak = data.facts?.streak {
        HStack(spacing: 12) {
          StatTile(label: "Current streak", value: streak.current.formatted(), unit: "days",
                   systemImage: "flame.fill", tint: .fuelVoltInk)
          StatTile(label: "Best streak", value: streak.best.formatted(), unit: "days",
                   systemImage: "trophy.fill", tint: .fuelGoldInk)
        }
      }

      if !data.insights.isEmpty {
        VStack(spacing: 12) {
          ForEach(data.insights) { insight in
            VStack(alignment: .leading, spacing: 4) {
              Text(insight.title)
                .font(.fuelBody(.subheadline, weight: 600))
                .foregroundStyle(Color.fuelInk)
              Text(insight.body)
                .font(.fuelBody(.subheadline))
                .foregroundStyle(Color.fuelSubtle)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .fuelCard()
          }
        }
      }

      if !data.tips.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          Text("Try today").fuelEyebrow()
          ForEach(data.tips, id: \.self) { tip in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
                .font(.fuelBody(.subheadline))
                .foregroundStyle(Color.fuelVoltInk)
              Text(tip)
                .font(.fuelBody(.subheadline))
                .foregroundStyle(Color.fuelInk)
                .fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 0)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .fuelCard()
      }

      Text(data.cached == true ? "Updated today · cached" : "Updated just now")
        .font(.fuelBody(.caption))
        .foregroundStyle(Color.fuelSubtle)
    }
  }
}

private struct InsightsSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Coach").fuelEyebrow()
        Text("Reading your last two weeks…")
          .font(.fuelTitle2)
          .foregroundStyle(Color.fuelInk)
      }
      ForEach(0..<2, id: \.self) { _ in
        VStack(alignment: .leading, spacing: 6) {
          Text("A steady week")
            .font(.fuelBody(.subheadline, weight: 600))
          Text("You've been hitting your protein target most days this week.")
            .font(.fuelBody(.subheadline))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .fuelCard()
      }
    }
    .redacted(reason: .placeholder)
  }
}

// MARK: - Suggestions

private struct SuggestionsSection: View {
  let state: CoachViewModel.SectionState<SuggestResponse>
  let remaining: RemainingMacros
  let refreshing: Bool
  var onRefresh: () -> Void
  var onRetry: () -> Void
  var onLog: (CatalogMeal) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      content
    }
  }

  private var isTargetReached: Bool {
    if case let .ready(data) = state { return data.targetReached }
    return false
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Up next").fuelEyebrow()
        Text("What fits right now")
          .font(.fuelTitle2)
          .foregroundStyle(Color.fuelInk)
        if !isTargetReached {
          Text(basisLine)
            .font(.fuelMono(.caption))
            .foregroundStyle(Color.fuelSubtle)
            .contentTransition(.numericText())
        }
      }
      Spacer()
      Button(action: onRefresh) {
        Image(systemName: "arrow.clockwise")
          .rotationEffect(.degrees(refreshing ? 360 : 0))
          .animation(refreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: refreshing)
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color.fuelSubtle)
      .disabled(refreshing)
      .accessibilityLabel("Refresh suggestions")
    }
  }

  private var basisLine: String {
    String(
      localized: "\(remaining.calories) kcal · \(remaining.protein)g P · \(remaining.carbs)g C · \(remaining.fat)g F left"
    )
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .loading:
      SuggestionsSkeleton()
    case .unavailable:
      UnavailableCard(eyebrow: nil, message: "Suggestions are warming up — check back soon.")
    case let .failed(error):
      SectionErrorCard(eyebrow: nil, error: error, onRetry: onRetry)
    case let .ready(data):
      if data.targetReached {
        goalHitCard
      } else if data.suggestions.isEmpty {
        Text("Add a few meals to your library and suggestions will appear here.")
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .fuelCard()
      } else {
        VStack(spacing: 12) {
          ForEach(data.suggestions) { suggestion in
            SuggestionCard(suggestion: suggestion, onLog: { onLog(suggestion.meal) })
          }
        }
      }
    }
  }

  private var goalHitCard: some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.title2)
        .foregroundStyle(Color.fuelVoltInk)
      VStack(alignment: .leading, spacing: 2) {
        Text("Goal hit for today")
          .font(.fuelHeading(.headline))
          .foregroundStyle(Color.fuelInk)
        Text("You've covered your calories — nice work.")
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .fuelCard()
  }
}

private struct SuggestionCard: View {
  let suggestion: MealSuggestion
  var onLog: () -> Void

  private var meal: CatalogMeal { suggestion.meal }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(meal.name)
            .font(.fuelHeading(.headline))
            .foregroundStyle(Color.fuelInk)
            .lineLimit(2)
          if let serving = meal.servingSize?.trimmingCharacters(in: .whitespaces), !serving.isEmpty {
            Text(serving)
              .font(.fuelBody(.caption))
              .foregroundStyle(Color.fuelSubtle)
          }
          HStack(spacing: 12) {
            macro("P", Int(meal.protein.rounded()), MacroPalette.proteinInk)
            macro("C", Int(meal.carbs.rounded()), MacroPalette.carbsInk)
            macro("F", Int(meal.fat.rounded()), MacroPalette.fatInk)
          }
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 1) {
          Text("\(Int(meal.calories.rounded()))")
            .font(.fuelMono(.headline, weight: 600))
            .foregroundStyle(Color.fuelInk)
          Text("kcal").fuelEyebrow()
        }
      }

      Text(suggestion.reason)
        .font(.fuelBody(.footnote))
        .italic()
        .foregroundStyle(Color.fuelSubtle)
        .fixedSize(horizontal: false, vertical: true)

      Button(action: onLog) {
        Label("Log", systemImage: "plus")
          .font(.fuelBody(.subheadline, weight: 600))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 2)
      }
      .buttonStyle(.glass)
      .tint(.fuelCitrus)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fuelCard()
  }

  private func macro(_ letter: String, _ grams: Int, _ ink: Color) -> some View {
    HStack(spacing: 2) {
      Text(letter).font(.fuelMono(.caption, weight: 700)).foregroundStyle(ink)
      Text("\(grams)g").font(.fuelMono(.caption)).foregroundStyle(Color.fuelSubtle)
    }
  }
}

private struct SuggestionsSkeleton: View {
  var body: some View {
    VStack(spacing: 12) {
      ForEach(0..<3, id: \.self) { _ in
        VStack(alignment: .leading, spacing: 8) {
          Text("Grilled chicken breast").font(.fuelHeading(.headline))
          Text("High in protein, fits your remaining macros.").font(.fuelBody(.footnote))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .fuelCard()
      }
    }
    .redacted(reason: .placeholder)
  }
}

// MARK: - Shared cards

private struct UnavailableCard: View {
  var eyebrow: LocalizedStringKey?
  let message: LocalizedStringKey

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let eyebrow {
        Text(eyebrow).fuelEyebrow()
      }
      HStack(spacing: 8) {
        Image(systemName: "sparkles")
          .foregroundStyle(Color.fuelSubtle)
        Text(message)
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .fuelCard()
  }
}

private struct SectionErrorCard: View {
  var eyebrow: LocalizedStringKey?
  let error: PresentableError
  var onRetry: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let eyebrow {
        Text(eyebrow).fuelEyebrow()
      }
      ErrorBanner(error: error, onRetry: onRetry, onDismiss: nil)
    }
  }
}

#Preview {
  CoachView()
    .environment(AppState())
}
