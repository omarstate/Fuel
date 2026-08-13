import SwiftUI

// Pick a workout type → insert an in_progress session → hand the new id to the
// host, which opens the full-screen active session. Port of
// workouts/session/start-session-dialog.tsx.
struct StartSessionSheet: View {
  var onStarted: (UUID) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var categories: [WorkoutCategory] = []
  @State private var isLoading = true
  @State private var error: PresentableError?
  /// The category whose tile is showing its in-flight spinner.
  @State private var startingSlug: String?

  private let repository = WorkoutSessionRepository()
  private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("What are you training?")
            .font(.fuelTitle2)
            .foregroundStyle(Color.fuelInk)

          if let error {
            ErrorBanner(
              error: error,
              onRetry: { Task { await load() } },
              onDismiss: { self.error = nil }
            )
          }

          if isLoading {
            LazyVGrid(columns: columns, spacing: 12) {
              ForEach(0..<6, id: \.self) { _ in
                tileLabel(name: "Push day", description: "Chest, shoulders, triceps")
                  .redacted(reason: .placeholder)
              }
            }
          } else if categories.isEmpty {
            ContentUnavailableView(
              "No workout types",
              systemImage: "dumbbell",
              description: Text("The catalog hasn't loaded any categories yet.")
            )
          } else {
            LazyVGrid(columns: columns, spacing: 12) {
              ForEach(categories) { category in
                tile(category)
              }
            }
          }
        }
        .padding(16)
      }
      .background(Color.fuelBackground)
      .navigationTitle("Start session")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .task { await load() }
  }

  // MARK: - Tiles

  private func tile(_ category: WorkoutCategory) -> some View {
    Button {
      Task { await start(category) }
    } label: {
      ZStack(alignment: .topTrailing) {
        tileLabel(name: category.name, description: category.description)
        if startingSlug == category.slug {
          ProgressView()
            .controlSize(.small)
            .padding(10)
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(startingSlug != nil)
  }

  private func tileLabel(name: String, description: String?) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(name)
        .font(.fuelBody(.body, weight: 600))
        .foregroundStyle(Color.fuelInk)
        .lineLimit(1)
      Text(description ?? " ")
        .font(.fuelBody(.footnote))
        .foregroundStyle(Color.fuelSubtle)
        .lineLimit(2, reservesSpace: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .fuelCard(radius: FuelRadius.small + 4)
  }

  // MARK: - Actions

  private func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      categories = try await FuelAPI.workoutCategories()
      error = nil
    } catch {
      self.error = PresentableError(error)
    }
  }

  private func start(_ category: WorkoutCategory) async {
    startingSlug = category.slug
    defer { startingSlug = nil }
    do {
      let userID = try await repository.userID()
      let session = WorkoutSession(
        id: UUID(),
        userId: userID,
        categoryId: category.id,
        categoryName: category.name,
        categorySlug: category.slug,
        status: .inProgress,
        startedAt: Date()
      )
      try await repository.insertSession(session)
      dismiss()
      onStarted(session.id)
    } catch {
      self.error = PresentableError(error)
    }
  }
}

#Preview {
  StartSessionSheet(onStarted: { _ in })
}
