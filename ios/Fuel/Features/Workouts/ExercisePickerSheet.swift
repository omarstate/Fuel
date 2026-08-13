import SwiftUI

// The full exercise picker, presented from a live session. It replaced a wall of
// thirty identical capsules: once the catalog is more than a handful of names,
// choosing needs search, categories and — above all — memory of what you
// actually do, which is why "Recent" sits above the catalog.
//
// Deliberately dumb about writing: it reports a pick and nothing else. The HOST
// owns the optimistic add and the dismissal, so this sheet has no view model, no
// error state, and never closes itself.
struct ExercisePickerSheet: View {
  /// Precomputed by the host from its recent-sessions fetch.
  let recents: [ExercisePicker.Recent]
  /// Lowercased names already in the session — those rows show as "added".
  let existingNames: Set<String>
  /// The session's category, used to preselect a chip.
  let initialCategorySlug: String?
  /// The host's already-fetched catalog slice, shown flat if the grouped call
  /// fails. Not in the original sketch, but the specified soft-fail needs
  /// SOMETHING to fall back to.
  var fallbackCatalog: [Workout] = []
  /// (name, workoutId) — the host adds the exercise and dismisses.
  var onPick: (String, String?) -> Void

  @State private var query = ""
  /// Every category with its workouts. Empty means the call has not landed or
  /// failed; both degrade to `fallbackCatalog`.
  @State private var groups: [GroupedWorkouts] = []
  /// nil = the "All" chip.
  @State private var selectedSlug: String?
  @FocusState private var searchFocused: Bool

  private static let recentLimit = 8

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      searchField
      chips
      list
    }
    .padding(.top, 12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.fuelBackground.ignoresSafeArea())
    .task { await loadGroups() }
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("Add exercise").fuelEyebrow(color: .fuelWorkoutInk)
      Text("Pick an exercise")
        .font(.fuelTitle)
        .foregroundStyle(Color.fuelInk)
    }
    .padding(.horizontal, 16)
  }

  // Same recipe as WorkoutLibraryView's inline search, so the two lists of
  // exercises are searched by the same-looking field.
  private var searchField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.body)
        .foregroundStyle(Color.fuelSubtle)
      TextField("Search exercises", text: $query)
        .font(.fuelBody(.body))
        .foregroundStyle(Color.fuelInk)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .focused($searchFocused)
      if !query.isEmpty {
        Button {
          query = ""
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
    .padding(.horizontal, 16)
  }

  // MARK: - Category chips

  @ViewBuilder
  private var chips: some View {
    if !groups.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          chip(title: String(localized: "All"), selected: selectedSlug == nil) { selectedSlug = nil }
          ForEach(groups) { group in
            chip(title: group.category.name, selected: selectedSlug == group.category.slug) {
              selectedSlug = group.category.slug
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
      }
      .scrollClipDisabled()
    }
  }

  // Orange treatment on selection — the workout accent, matching the session's
  // own chrome rather than the Library's dark-ink pill.
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

  // MARK: - List

  private var list: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 10) {
        if !visibleRecents.isEmpty {
          Text("Recent").fuelEyebrow()
          ForEach(visibleRecents) { recent in
            row(
              name: recent.name,
              workoutId: recent.workoutId,
              subtitle: recent.lastSetLabel.map { String(localized: "Last: \($0)") },
              monoSubtitle: true
            )
          }
        }

        if !filteredCatalog.isEmpty {
          Text(catalogSectionTitle)
            .fuelEyebrow()
            .padding(.top, visibleRecents.isEmpty ? 0 : 6)
          ForEach(filteredCatalog) { workout in
            row(
              name: workout.name,
              workoutId: workout.id,
              subtitle: metaLine(workout),
              monoSubtitle: false
            )
          }
        }

        if showAddCustom {
          Text("Not in the catalog").fuelEyebrow()
          customRow
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 24)
      .animation(.snappy, value: filteredCatalog.map(\.id))
    }
    .scrollDismissesKeyboard(.interactively)
  }

  // A row is one flat card with a 44pt+ target, the same silhouette the Library
  // uses for a catalog exercise — just tappable here.
  private func row(name: String, workoutId: String?, subtitle: String?, monoSubtitle: Bool) -> some View {
    let added = existingNames.contains(name.lowercased())
    return Button {
      onPick(name, workoutId)
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(name)
            .font(.fuelBody(.body, weight: 600))
            .foregroundStyle(Color.fuelInk)
            .lineLimit(2)
          if let subtitle {
            Text(subtitle)
              .font(monoSubtitle ? .fuelMono(.footnote) : .fuelBody(.footnote))
              .foregroundStyle(Color.fuelSubtle)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 8)
        Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
          .font(.system(size: 20))
          .foregroundStyle(added ? Color.fuelSubtle : Color.fuelWorkout)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .fuelCard()
      .opacity(added ? 0.5 : 1)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(added)
    .accessibilityLabel(added ? String(localized: "\(name), already in this session") : name)
  }

  // The escape hatch that replaced the free-text field on the session screen:
  // search for something the catalog has never heard of and you can still log it.
  private var customRow: some View {
    Button {
      onPick(trimmedQuery, nil)
    } label: {
      HStack(spacing: 12) {
        Text("Add \"\(trimmedQuery)\"")
          .font(.fuelBody(.body, weight: 600))
          .foregroundStyle(Color.fuelInk)
          .lineLimit(2)
        Spacer(minLength: 8)
        Image(systemName: "plus.circle.fill")
          .font(.system(size: 20))
          .foregroundStyle(Color.fuelWorkout)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .fuelCard()
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Derived

  private var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Recents are the "what you always do" shortcut, so they only make sense
  /// before you have started narrowing by name.
  private var visibleRecents: [ExercisePicker.Recent] {
    trimmedQuery.isEmpty ? Array(recents.prefix(Self.recentLimit)) : []
  }

  /// Workouts for the selected chip. With no chip, every workout once — a
  /// workout tagged Push AND Upper body appears in two groups.
  private var pool: [Workout] {
    if let selectedSlug {
      return groups.first(where: { $0.category.slug == selectedSlug })?.workouts ?? []
    }
    guard !groups.isEmpty else { return fallbackCatalog }
    var seen = Set<String>()
    var out: [Workout] = []
    for group in groups {
      for workout in group.workouts where !seen.contains(workout.id) {
        seen.insert(workout.id)
        out.append(workout)
      }
    }
    return out
  }

  private var filteredCatalog: [Workout] {
    pool.filter { ExercisePicker.matches(name: $0.name, query: trimmedQuery) }
  }

  private var catalogSectionTitle: String {
    guard let selectedSlug,
          let name = groups.first(where: { $0.category.slug == selectedSlug })?.category.name
    else { return String(localized: "Exercises") }
    return name
  }

  private var showAddCustom: Bool {
    !trimmedQuery.isEmpty && filteredCatalog.isEmpty
  }

  private func metaLine(_ workout: Workout) -> String? {
    let parts = [workout.primaryMuscle, workout.equipment]
      .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  // MARK: - Loading

  // Soft-fail like the session's own catalog fetch: the recents and the host's
  // flat slice still let you add something, which beats an error over a sheet you
  // opened mid-set.
  private func loadGroups() async {
    guard groups.isEmpty else { return }
    guard let result = try? await FuelAPI.workoutsGrouped() else { return }
    let usable = result.filter { !$0.workouts.isEmpty }
    withAnimation(.snappy) {
      groups = usable
      if let initialCategorySlug, usable.contains(where: { $0.category.slug == initialCategorySlug }) {
        selectedSlug = initialCategorySlug
      }
    }
  }
}

#Preview {
  ExercisePickerSheet(
    recents: [
      .init(name: "Barbell bench press", workoutId: "w1", lastWeight: 80, lastReps: 8),
      .init(name: "Incline dumbbell press", workoutId: "w2", lastWeight: 27.5, lastReps: 10),
      .init(name: "Pull-up", workoutId: nil, lastWeight: nil, lastReps: 12),
      .init(name: "Cable fly", workoutId: "w3", lastWeight: nil, lastReps: nil),
    ],
    existingNames: ["cable fly"],
    initialCategorySlug: "push",
    fallbackCatalog: [
      Workout(
        id: "w9", name: "Overhead press", description: nil,
        primaryMuscle: "Shoulders", equipment: "Barbell",
        targetSets: 4, targetReps: "6-8", categories: [], createdAt: nil
      )
    ],
    onPick: { _, _ in }
  )
}
