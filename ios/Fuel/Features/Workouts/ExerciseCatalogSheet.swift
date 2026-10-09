import SwiftUI

// "Browse exercises" — the ~870-exercise free-exercise-db mirror, one tap from
// the Workout Library. It exists because the alternative is typing every
// movement into WorkoutForm by hand: name, muscle, equipment, description.
//
// Chrome is deliberately the Library's, not ExercisePickerSheet's: the same
// inline search field and the same count eyebrow, because this is browsing a
// catalog, not picking mid-set. The two filters are split by shape — muscle is
// the one you reach for constantly, so it gets the scrolling chip row; category
// is occasional, so it hides in a toolbar menu.
struct ExerciseCatalogSheet: View {
  /// Called on dismiss ONLY when something was actually added, so a browse that
  /// adds nothing costs the Library no refetch.
  var onAdded: () -> Void = {}

  @Environment(\.dismiss) private var dismiss
  @State private var model = ExerciseCatalogViewModel()

  var body: some View {
    @Bindable var model = model

    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          searchField
          muscleChips
          countLine

          if let error = model.error {
            ErrorBanner(
              error: error,
              onRetry: model.exercises.isEmpty ? { Task { await model.refresh() } } : nil,
              onDismiss: { model.error = nil }
            )
          }

          if model.showSkeleton {
            ForEach(0..<6, id: \.self) { _ in
              ExerciseCatalogRow(
                exercise: .placeholder,
                isInLibrary: false,
                isAdding: false,
                onAdd: {}
              )
              .redacted(reason: .placeholder)
            }
          } else if model.isEmpty {
            emptyState
          } else {
            ForEach(model.exercises) { exercise in
              ExerciseCatalogRow(
                exercise: exercise,
                isInLibrary: model.isInLibrary(exercise),
                isAdding: model.addingSlug == exercise.slug,
                onAdd: { Task { await model.add(exercise) } }
              )
              .onAppear {
                if exercise.slug == model.exercises.last?.slug {
                  Task { await model.loadMore() }
                }
              }
            }
            footer
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .animation(.snappy, value: model.addedSlugs)
      }
      .scrollDismissesKeyboard(.interactively)
      .background(Color.fuelBackground)
      .scrollEdgeEffectStyle(.soft, for: .top)
      .navigationTitle("Browse exercises")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Done") { finish() }
        }
        ToolbarItem(placement: .topBarTrailing) { categoryMenu }
      }
      .refreshable { await model.refresh() }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .task { await model.start() }
    .onChange(of: model.searchText) { model.searchTextChanged() }
    .onChange(of: model.category) { Task { await model.reload() } }
    .onChange(of: model.muscle) { Task { await model.reload() } }
    // Covers the drag-to-dismiss path too, which never reaches `finish()`.
    .onDisappear { if model.didAddAny { onAdded() } }
    .sensoryFeedback(.success, trigger: model.addedSlugs.count)
  }

  private func finish() {
    dismiss()
  }

  // MARK: - Search

  // Same recipe as WorkoutLibraryView's inline field so the two lists of
  // exercises are searched by the same-looking control.
  private var searchField: some View {
    @Bindable var model = model
    return HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.body)
        .foregroundStyle(Color.fuelSubtle)
      TextField("Search exercises", text: $model.searchText)
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
    .frame(minHeight: 44)
    .background(Color.fuelSurface, in: RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
        .strokeBorder(Color.fuelInk.opacity(0.08), lineWidth: 1)
    )
  }

  // MARK: - Muscle chips

  private var muscleChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        chip(title: String(localized: "All"), selected: model.muscle == nil) {
          model.muscle = nil
        }
        ForEach(ExerciseCatalogFilters.muscles, id: \.self) { muscle in
          chip(title: CatalogExercise.titleCased(muscle), selected: model.muscle == muscle) {
            model.muscle = muscle
          }
        }
      }
      .padding(.vertical, 2)
    }
    .scrollClipDisabled()
  }

  // Orange on selection — the workouts accent, matching ExercisePickerSheet
  // rather than the Library's dark-ink pill, because this sheet is an action
  // surface rather than the tab itself.
  private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(.snappy) { action() }
    } label: {
      Text(title)
        .font(.fuelMono(.caption, weight: 600))
        .textCase(.uppercase)
        .tracking(0.6)
        .foregroundStyle(selected ? Color.fuelWorkoutInk : Color.fuelSubtle)
        .padding(.horizontal, 14)
        .frame(minHeight: 34)
        .background(
          selected ? Color.fuelWorkout.opacity(0.18) : Color.fuelSurface,
          in: Capsule()
        )
        .overlay(
          Capsule().strokeBorder(Color.fuelInk.opacity(selected ? 0 : 0.1), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Category menu

  private var categoryMenu: some View {
    Menu {
      Picker("Category", selection: Binding(
        get: { model.category ?? "" },
        set: { model.category = $0.isEmpty ? nil : $0 }
      )) {
        Text("All categories").tag("")
        ForEach(ExerciseCatalogFilters.categories, id: \.self) { category in
          Text(CatalogExercise.titleCased(category)).tag(category)
        }
      }
    } label: {
      Label("Filter", systemImage: model.category == nil
        ? "line.3.horizontal.decrease.circle"
        : "line.3.horizontal.decrease.circle.fill")
    }
    .tint(.fuelWorkoutInk)
  }

  // MARK: - Count + footer

  @ViewBuilder
  private var countLine: some View {
    if model.hasLoadedOnce && !model.exercises.isEmpty {
      Text("Exercises \(model.total)")
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
    } else {
      HStack {
        Spacer()
        Text("\(model.exercises.count) of \(model.total)")
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
    } else if model.hasFilters {
      ContentUnavailableView {
        Label("Nothing matches those filters", systemImage: "line.3.horizontal.decrease.circle")
      } description: {
        Text("Try a different muscle or category.")
      } actions: {
        Button("Clear filters") { withAnimation(.snappy) { model.clearFilters() } }
          .buttonStyle(.glass)
          .tint(.fuelWorkoutInk)
      }
      .padding(.top, 40)
    } else {
      // The only way to land here with no filters is an empty table — i.e. the
      // import has never been run. Say so plainly instead of "no results".
      ContentUnavailableView {
        Label("No exercises yet", systemImage: "square.stack.3d.up.slash")
      } description: {
        Text("The exercise dataset hasn't been imported yet. Ask an admin to run the import.")
      }
      .padding(.top, 40)
    }
  }
}

#Preview {
  ExerciseCatalogSheet()
}
