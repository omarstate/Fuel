import SwiftUI

// The Workout Library tab: the shared exercise catalog, chrome-for-chrome the
// same as the meals Library (editorial masthead, inline search, mono-uppercase
// category chips with a dark-ink selected pill, a count eyebrow, flat cards,
// "N of M" footer + infinite scroll). Port of workouts/workout-library.tsx.
//
// Read-only apart from "Add workout": picking an exercise happens inside a live
// session, not here, so a card has no add button — unlike MealCatalogCard.
struct WorkoutLibraryView: View {
  @State private var model = WorkoutLibraryViewModel()
  @State private var showCreate = false

  var body: some View {
    @Bindable var model = model

    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
          header
          searchField
          chips
          countLine

          if let error = model.error, model.workouts.isEmpty {
            ErrorBanner(
              error: error,
              onRetry: { Task { await model.refresh() } },
              onDismiss: { model.error = nil }
            )
          }

          if model.showSkeleton {
            ForEach(0..<6, id: \.self) { _ in
              WorkoutCatalogCard(workout: .placeholder)
                .redacted(reason: .placeholder)
            }
          } else if model.isEmpty {
            emptyState
          } else {
            ForEach(model.workouts) { workout in
              WorkoutCatalogCard(workout: workout)
                .onAppear {
                  if workout.id == model.workouts.last?.id {
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
    }
    .task { await model.start() }
    .onChange(of: model.searchText) { model.searchTextChanged() }
    .onChange(of: model.category) { Task { await model.reload() } }
    .sheet(isPresented: $showCreate) {
      WorkoutForm { _ in Task { await model.invalidate() } }
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Workouts · Library").fuelEyebrow(color: .fuelWorkoutInk)
          Text("Workout library")
            .font(.fuelMasthead)
            .foregroundStyle(Color.fuelInk)
        }
        Spacer()
        Button {
          showCreate = true
        } label: {
          Label("Add", systemImage: "plus")
            .font(.fuelBody(.subheadline, weight: 600))
        }
        .buttonStyle(.glassProminent)
        .tint(.fuelWorkout)
      }
      Text("Browse the shared catalog and add your own, tagged with every type they belong to.")
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
    }
  }

  // MARK: - Search

  private var searchField: some View {
    @Bindable var model = model
    return HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.body)
        .foregroundStyle(Color.fuelSubtle)
      TextField("Search workouts", text: $model.searchText)
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
    if !model.workouts.isEmpty || model.hasLoadedOnce {
      Text("Workouts \(model.total)")
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
    } else if !model.workouts.isEmpty {
      HStack {
        Spacer()
        Text("\(model.workouts.count) of \(model.total)")
          .font(.fuelMono(.footnote))
          .foregroundStyle(Color.fuelSubtle)
        Spacer()
      }
      .padding(.vertical, 8)
    }
  }

  @ViewBuilder
  private var emptyState: some View {
    if !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
      ContentUnavailableView.search(text: model.searchText)
        .padding(.top, 40)
    } else {
      ContentUnavailableView {
        Label("No workouts here", systemImage: "dumbbell")
      } description: {
        Text("Try a different type — or add the first one to the catalog.")
      } actions: {
        Button("Add a workout") { showCreate = true }
          .buttonStyle(.glassProminent)
          .tint(.fuelWorkout)
      }
      .padding(.top, 40)
    }
  }
}

#Preview {
  WorkoutLibraryView()
}
