import SwiftUI

// The Library tab: an editorial header (eyebrow → "Library" masthead → sub-line),
// an inline search field, mono-uppercase category chips (selected = dark ink
// pill), a "MEALS N" count, then the shared Egypt-first catalog as flat meal
// cards. Each card opens the meal detail on tap and logs via "+ Add to today".
// "My meals" is a pushed screen. Infinite scroll + "X of N" pagination retained.
struct LibraryView: View {
  @Environment(AppState.self) private var app
  @State private var model = LibraryViewModel()
  @State private var showCreate = false
  @State private var showLookup = false
  @State private var logTarget: CatalogMeal?
  @State private var detailMeal: CatalogMeal?

  var body: some View {
    @Bindable var model = model

    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
          header
          searchField
          chips
          countLine

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
                onOpen: { detailMeal = meal },
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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
      }
      .background(Color.fuelBackground)
      .scrollEdgeEffectStyle(.soft, for: .top)
      .toolbar(.hidden, for: .navigationBar)
      .statusBarFade()
      .refreshable { await model.refresh() }
      .navigationDestination(item: $detailMeal) { meal in
        MealDetailView(
          summary: meal,
          onChanged: { Task { await model.invalidate() } },
          onDeleted: {}
        )
      }
      .navigationDestination(for: MyMealsRoute.self) { _ in
        MyMealsView()
      }
    }
    .task { await model.start() }
    .onChange(of: model.searchText) { model.searchTextChanged() }
    .onChange(of: model.category) { Task { await model.reload() } }
    .sheet(isPresented: $showCreate) {
      CatalogMealForm(mode: .create) { _ in Task { await model.invalidate() } }
    }
    .sheet(isPresented: $showLookup) {
      AILookupSheet()
    }
    .sheet(item: $logTarget) { meal in
      AddToLogSheet(meal: meal)
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Nutrition · Library").fuelEyebrow()
          Text("Library")
            .font(.fuelMasthead)
            .foregroundStyle(Color.fuelInk)
        }
        Spacer()
        NavigationLink(value: MyMealsRoute()) {
          Label("My meals", systemImage: "person.crop.circle")
            .font(.fuelBody(.subheadline, weight: 600))
            .foregroundStyle(Color.fuelInk)
            .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.glass)
      }
      Text("Browse the shared catalog and drop any meal straight into today's log.")
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)

      HStack(spacing: 10) {
        Button {
          showLookup = true
        } label: {
          Label("AI lookup", systemImage: "sparkles")
            .font(.fuelBody(.subheadline, weight: 600))
        }
        .buttonStyle(.glass)
        .tint(.fuelInk)

        Button {
          showCreate = true
        } label: {
          Label("Add meal", systemImage: "plus")
            .font(.fuelBody(.subheadline, weight: 600))
        }
        .buttonStyle(.glassProminent)
        .tint(.fuelCitrus)
      }
      .padding(.top, 2)
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
          chip(title: "All", selected: model.category == nil) { model.category = nil }
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

  // MARK: - Count + footer

  @ViewBuilder
  private var countLine: some View {
    if !model.displayedMeals.isEmpty || model.hasLoadedOnce {
      Text("Meals \(model.total)")
        .fuelEyebrow()
        .padding(.top, 2)
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
        Text("Try a different category — or add one to the catalog.")
      } actions: {
        Button("Add a meal") { showCreate = true }
          .buttonStyle(.glassProminent)
          .tint(.fuelCitrus)
      }
      .padding(.top, 40)
    }
  }
}

// Value-typed route so "My meals" can be pushed via `navigationDestination(for:)`.
struct MyMealsRoute: Hashable {}

extension CatalogMeal {
  // A neutral placeholder used behind redacted skeleton cards on first load.
  static let placeholder = CatalogMeal(
    id: "placeholder", name: "Meal name", description: nil, servingSize: "1 serving",
    calories: 500, protein: 30, carbs: 45, fat: 18,
    category: .init(id: "c", name: "Category", slug: "category"),
    createdBy: nil, createdAt: Date(), aiSource: nil, sourceUrl: nil, macroRanges: nil
  )
}

#Preview {
  LibraryView()
    .environment(AppState())
}
