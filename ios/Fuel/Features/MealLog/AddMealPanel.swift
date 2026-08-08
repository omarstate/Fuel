import SwiftUI

// The full-screen "add to this section" panel, opened by the inline "+ Add" on an
// empty Today section. It answers "what goes in Breakfast?" with every path in
// one place: an editorial header naming the section, a row of glass chips for the
// non-catalog methods (voice → barcode → photo → AI estimate → manual, voice
// first because it's the fastest), then the shared Egypt-first catalog browsed
// exactly like the Library tab (search, category chips, "MEALS N", paginated
// cards). Every card logs straight into the section that opened the panel.
// Barcode opens on its chooser: quick-log scans land in this panel's section
// (preselected), add-to-library saves show up in the list below ready to log.
//
// The panel deliberately STAYS OPEN after a log so several meals land in one
// visit; Today reconciles behind it through `logRevision`. Closing is the X only.
struct AddMealPanel: View {
  let mealType: MealType

  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var app

  // A fresh Library view model — same logic as the Library tab (debounced search,
  // cached pages, infinite scroll), just scoped to this presentation.
  @State private var model = LibraryViewModel()
  @State private var logTarget: CatalogMeal?
  @State private var showManual = false
  @State private var showVoice = false
  @State private var showEstimate = false
  @State private var showPhoto = false
  @State private var showBarcode = false

  private let repo = MealLogRepository()

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
          header
          methodRow
          searchField
          chips
          countLine
          catalog
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
      }
      .background(Color.fuelBackground)
      .scrollEdgeEffectStyle(.soft, for: .top)
      .toolbar(.hidden, for: .navigationBar)
      .statusBarFade()
      .refreshable { await model.refresh() }
    }
    .task { await model.start() }
    .onChange(of: model.searchText) { model.searchTextChanged() }
    .onChange(of: model.category) { Task { await model.reload() } }
    // Each flow keeps the exact presentation style Today uses for it, so the
    // panel feels like a shortcut into the same screens (barcode is a cover).
    .sheet(item: $logTarget) { meal in
      AddToLogSheet(meal: meal, preselectedType: mealType)
    }
    .sheet(isPresented: $showManual) {
      ManualAddSheet(onSave: { new in try await log(new) }, preselectedType: mealType)
    }
    .sheet(isPresented: $showVoice) { VoiceLogFlow() }
    .sheet(isPresented: $showEstimate) { AIEstimateFlow() }
    .sheet(isPresented: $showPhoto) { PhotoLabelFlow() }
    .fullScreenCover(isPresented: $showBarcode) {
      // Quick-log scans preselect this panel's section; add-to-library saves
      // drop the cached pages so the new product appears behind the cover.
      BarcodeScanView(preselectedType: mealType) { _ in Task { await model.invalidate() } }
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Add to").fuelEyebrow(color: .fuelVoltInk)
          Text(mealType.label)
            .font(.fuelMasthead)
            .foregroundStyle(Color.fuelInk)
        }
        Spacer()
        closeButton
      }
      Text("Log with your voice, a scan, or pick from the catalog below.")
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
    }
  }

  private var closeButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "xmark")
        .font(.body.weight(.semibold))
        .frame(width: 22, height: 22)
    }
    .buttonStyle(.glass)
    .buttonBorderShape(.circle)
    .tint(.fuelInk)
    .frame(minWidth: 44, minHeight: 44)
    .accessibilityLabel("Close")
  }

  // MARK: - Log methods

  // The non-catalog paths as a scrolling row of glass chips. Voice leads and is
  // the one prominent chip — it's the fastest way to log a meal.
  private var methodRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(LogMethod.allCases) { method in
          Button {
            open(method)
          } label: {
            Label(method.title, systemImage: method.systemImage)
              .font(.fuelBody(.subheadline, weight: 600))
              .lineLimit(1)
          }
          .buttonStyle(.glass)
          .tint(method == .voice ? .fuelCitrus : .fuelInk)
          .frame(minHeight: 44)
        }
      }
      .padding(.vertical, 2)
    }
    .scrollClipDisabled()
  }

  private func open(_ method: LogMethod) {
    switch method {
    case .voice: showVoice = true
    case .barcode: showBarcode = true
    case .photo: showPhoto = true
    case .estimate: showEstimate = true
    case .manual: showManual = true
    }
  }

  // MARK: - Search

  private var searchField: some View {
    @Bindable var model = model
    return HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.body)
        .foregroundStyle(Color.fuelSubtle)
      TextField("Search meals", text: $model.searchText)
        .font(.fuelBody(.body))
        .foregroundStyle(Color.fuelInk)
        .autocorrectionDisabled()
        .submitLabel(.search)
      if !model.searchText.isEmpty {
        Button {
          model.searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(Color.fuelSubtle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear search")
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 11)
    .background(Color.fuelSurface, in: RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
        .strokeBorder(Color.fuelInk.opacity(0.08), lineWidth: 1)
    )
  }

  // MARK: - Category chips

  @ViewBuilder
  private var chips: some View {
    if !model.categories.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          chip(title: String(localized: "All"), selected: model.category == nil) { model.category = nil }
          ForEach(model.categories) { category in
            chip(title: category.name, selected: model.category?.id == category.id) {
              model.category = category
            }
          }
        }
        .padding(.vertical, 2)
      }
      .scrollClipDisabled()
    }
  }

  private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(.snappy) { action() }
    } label: {
      Text(title)
        .font(.fuelMono(.caption, weight: 600))
        .textCase(.uppercase)
        .tracking(0.6)
        .foregroundStyle(selected ? Color.fuelBackground : Color.fuelSubtle)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
          selected ? Color.fuelInk : Color.fuelSurface,
          in: Capsule()
        )
        .overlay(
          Capsule().strokeBorder(Color.fuelInk.opacity(selected ? 0 : 0.1), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Catalog

  @ViewBuilder
  private var countLine: some View {
    if !model.displayedMeals.isEmpty || model.hasLoadedOnce {
      Text("Meals \(model.total)")
        .fuelEyebrow()
        .padding(.top, 2)
    }
  }

  // Inside the panel the intent is logging, not browsing: the whole card and the
  // "+ Add to today" pill both open AddToLogSheet preselected to this section.
  @ViewBuilder
  private var catalog: some View {
    if let error = model.error, model.displayedMeals.isEmpty {
      ErrorBanner(error: error, onRetry: { Task { await model.refresh() } }, onDismiss: { model.error = nil })
    }

    if model.isEmpty {
      emptyState
    } else if showSkeleton {
      ForEach(0..<6, id: \.self) { _ in
        MealCatalogCard(meal: .placeholder)
          .redacted(reason: .placeholder)
      }
    } else {
      ForEach(model.displayedMeals) { meal in
        MealCatalogCard(
          meal: meal,
          onOpen: { logTarget = meal },
          onAdd: { logTarget = meal }
        )
        .onAppear {
          if meal.id == model.displayedMeals.last?.id {
            Task { await model.loadMore() }
          }
        }
      }
      footer
    }
  }

  @ViewBuilder
  private var footer: some View {
    if model.isLoadingMore {
      HStack {
        Spacer()
        ProgressView().controlSize(.small)
        Spacer()
      }
      .padding(.vertical, 8)
    } else if !model.displayedMeals.isEmpty {
      HStack {
        Spacer()
        Text("\(model.displayedMeals.count) of \(model.total)")
          .font(.fuelMono(.footnote))
          .foregroundStyle(Color.fuelSubtle)
        Spacer()
      }
      .padding(.vertical, 8)
    }
  }

  private var showSkeleton: Bool { !model.hasLoadedOnce && model.isLoading }

  @ViewBuilder
  private var emptyState: some View {
    if !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
      ContentUnavailableView.search(text: model.searchText)
        .padding(.top, 40)
    } else {
      ContentUnavailableView {
        Label("No meals match", systemImage: "magnifyingglass")
      } description: {
        Text("Try another category — or enter this meal yourself.")
      } actions: {
        Button("Add manually") { showManual = true }
          .buttonStyle(.glassProminent)
          .tint(.fuelCitrus)
      }
      .padding(.top, 40)
    }
  }

  // MARK: - Manual write

  // The panel owns no meal-log view model, so a manual entry goes straight to the
  // repository and bumps `logRevision`; Today refreshes from that (same contract
  // as AddToLogSheet).
  private func log(_ new: ManualAddSheet.NewMeal) async throws {
    let userID = try await repo.userID()
    let entry = LoggedMeal(
      userId: userID,
      name: new.name,
      mealType: new.mealType,
      servingSize: new.servingSize,
      calories: new.calories,
      protein: new.protein,
      carbs: new.carbs,
      fat: new.fat,
      loggedAt: Date()
    )
    try await repo.insert(entry)
    app.bumpLogRevision()
  }
}

// The panel's chip row: the log paths that aren't "pick a catalog meal". Titles
// and icons come from `LogAction` wherever a case exists so the wording matches
// the bottom bar's plus menu; `manual` is the one path the enum doesn't cover.
private enum LogMethod: String, CaseIterable, Identifiable {
  case voice
  case barcode
  case photo
  case estimate
  case manual

  var id: String { rawValue }

  private var action: LogAction? {
    switch self {
    case .voice: return .voice
    case .barcode: return .barcode
    case .photo: return .photo
    case .estimate: return .estimate
    case .manual: return nil
    }
  }

  var title: LocalizedStringKey { action?.title ?? "Add manually" }

  var systemImage: String { action?.systemImage ?? "square.and.pencil" }
}

#Preview {
  AddMealPanel(mealType: .breakfast)
    .environment(AppState())
}
