import SwiftUI

// The user's own catalog contributions, pushed from Library. Editorial header
// (eyebrow → "My meals" masthead → sub), then flat cards carrying a "MY RECIPE"
// badge with inline Edit / Remove buttons plus "+ Add to today". Edit reuses
// CatalogMealForm; Remove confirms then calls FuelAPI.deleteMeal.
struct MyMealsView: View {
  @Environment(AppState.self) private var app

  @State private var meals: [CatalogMeal] = []
  @State private var isLoading = true
  @State private var hasLoadedOnce = false
  @State private var error: PresentableError?

  @State private var showCreate = false
  @State private var editTarget: CatalogMeal?
  @State private var logTarget: CatalogMeal?
  @State private var detailMeal: CatalogMeal?
  @State private var removeTarget: CatalogMeal?
  @State private var deleteTick = 0

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 16) {
        header

        if let error {
          ErrorBanner(error: error, onRetry: { Task { await load() } }, onDismiss: { self.error = nil })
        }

        if isLoading && !hasLoadedOnce {
          ForEach(0..<3, id: \.self) { _ in
            MealCatalogCard(meal: .placeholder, myRecipe: true, onEdit: {}, onRemove: {})
              .redacted(reason: .placeholder)
          }
        } else if meals.isEmpty {
          emptyState
        } else {
          ForEach(meals) { meal in
            MealCatalogCard(
              meal: meal,
              onOpen: { detailMeal = meal },
              onAdd: { logTarget = meal },
              myRecipe: true,
              onEdit: { editTarget = meal },
              onRemove: { removeTarget = meal }
            )
          }
          Text("\(meals.count) \(meals.count == 1 ? "meal" : "meals")")
            .font(.fuelMono(.footnote))
            .foregroundStyle(Color.fuelSubtle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 24)
    }
    .background(Color.fuelBackground)
    .scrollEdgeEffectStyle(.soft, for: .top)
    .navigationTitle("My meals")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showCreate = true
        } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel("Add a meal")
      }
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: deleteTick)
    .task { await load() }
    .refreshable { await load() }
    .navigationDestination(item: $detailMeal) { meal in
      MealDetailView(
        summary: meal,
        onChanged: { Task { await load() } },
        onDeleted: { Task { await load() } }
      )
    }
    .sheet(isPresented: $showCreate) {
      CatalogMealForm(mode: .create) { _ in Task { await load() } }
    }
    .sheet(item: $editTarget) { meal in
      CatalogMealForm(mode: .edit(meal)) { _ in Task { await load() } }
    }
    .sheet(item: $logTarget) { meal in
      AddToLogSheet(meal: meal)
    }
    .confirmationDialog(
      removeTarget.map { "Delete \($0.name)?" } ?? "",
      isPresented: Binding(get: { removeTarget != nil }, set: { if !$0 { removeTarget = nil } }),
      titleVisibility: .visible,
      presenting: removeTarget
    ) { meal in
      Button("Delete", role: .destructive) {
        deleteTick += 1
        Task { await remove(meal) }
      }
      Button("Cancel", role: .cancel) {}
    } message: { _ in
      Text("This removes it from the shared catalog. This can't be undone.")
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Nutrition · My meals").fuelEyebrow()
      Text("My meals")
        .font(.fuelMasthead)
        .foregroundStyle(Color.fuelInk)
      Text("The meals you've contributed to the catalog. Edit or remove them any time.")
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No meals yet", systemImage: "books.vertical")
    } description: {
      Text("Meals you add to the catalog show up here.")
    } actions: {
      Button("Add a meal") { showCreate = true }
        .buttonStyle(.glassProminent)
        .tint(.fuelCitrus)
    }
    .padding(.top, 40)
  }

  private func load() async {
    isLoading = true
    defer {
      isLoading = false
      hasLoadedOnce = true
    }
    do {
      meals = try await FuelAPI.myMeals()
      error = nil
    } catch {
      self.error = PresentableError.presentable(error)
    }
  }

  private func remove(_ meal: CatalogMeal) async {
    let snapshot = meals
    meals.removeAll { $0.id == meal.id }
    do {
      _ = try await FuelAPI.deleteMeal(id: meal.id)
    } catch {
      meals = snapshot
      self.error = PresentableError(error)
    }
  }
}

#Preview {
  NavigationStack {
    MyMealsView()
      .environment(AppState())
  }
}
