import SwiftUI

// The pieces an exercise detail screen is made of, shared by the two screens
// that show one: `ExerciseDetailView` (a browsed free-exercise-db row, with an
// Add button) and `WorkoutDetailView` (the copy of it that now lives in the
// library, with nothing to add). Both are looking at the same movement, so
// neither may invent its own photo box, attribute card or step list.

// MARK: - Demo photo

// The dataset ships 0–2 stills per exercise and NO video: frame 0 is the start
// position, frame 1 the end. Alternating the two on a ~1s beat is the standard
// trick for making a two-frame set read as the movement rather than as two
// unrelated photos.
//
// Both frames live in the ZStack at once and only their opacity changes, so:
//   • both AsyncImages start fetching on appear — the second frame is decoded
//     long before its first turn, so the loop never flickers or pops;
//   • the container is a fixed 3:2 box (every dataset image is 3:2, verified
//     against the source JPEGs), so nothing reflows between frames.
struct ExerciseDemoPhoto: View {
  let urls: [URL]

  @State private var frame = 0

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: FuelRadius.card, style: .continuous)
  }

  var body: some View {
    ZStack {
      // Sits behind both frames, so it covers the loading phase, a failed
      // fetch and the no-photo case with one state.
      placeholder

      ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
          switch phase {
          case .success(let image):
            image.resizable().scaledToFill()
          case .empty where index == 0:
            ProgressView().controlSize(.regular)
          default:
            Color.clear
          }
        }
        .opacity(index == frame ? 1 : 0)
      }
    }
    .frame(maxWidth: .infinity)
    .aspectRatio(3.0 / 2.0, contentMode: .fit)
    .background(Color.fuelInk.opacity(0.05))
    .clipShape(shape)
    .overlay(shape.strokeBorder(Color.fuelInk.opacity(0.06), lineWidth: 1))
    .overlay(alignment: .bottomTrailing) { frameIndicator }
    // Cancelled automatically when the view goes away, so there is no timer to
    // invalidate and nothing ticking behind the next push.
    .task(id: urls.count) {
      guard urls.count > 1 else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
          frame = (frame + 1) % urls.count
        }
      }
    }
    .accessibilityElement()
    .accessibilityLabel(urls.isEmpty ? Text("No demo photo") : Text("Demo photo"))
  }

  @ViewBuilder
  private var placeholder: some View {
    VStack(spacing: 8) {
      Image(systemName: "figure.strengthtraining.traditional")
        .font(.system(size: 34))
        .foregroundStyle(Color.fuelSubtle.opacity(0.6))
      if urls.isEmpty {
        Text("No demo photo")
          .font(.fuelBody(.footnote))
          .foregroundStyle(Color.fuelSubtle)
      }
    }
  }

  // Two dots, not a page control: it marks which half of the movement is on
  // screen without inviting a tap, since the loop drives itself.
  @ViewBuilder
  private var frameIndicator: some View {
    if urls.count > 1 {
      HStack(spacing: 5) {
        ForEach(urls.indices, id: \.self) { index in
          Circle()
            .fill(index == frame ? Color.fuelWorkoutInk : Color.fuelInk.opacity(0.25))
            .frame(width: 6, height: 6)
        }
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 6)
      .glassEffect(.regular, in: Capsule())
      .padding(12)
      .accessibilityHidden(true)
    }
  }
}

// MARK: - Attributes

// The scalar facts about a movement, each optional. A key/value card beats more
// pills here: these are answers to fixed questions, not a set of tags.
struct ExerciseAttributeCard: View {
  let rows: [Row]

  struct Row: Identifiable {
    let id: String
    let label: LocalizedStringKey
    let value: String

    /// Drops the row when the value is missing or blank, so a caller can list
    /// every field it *might* show and let the card decide.
    init?(_ id: String, _ label: LocalizedStringKey, _ value: String?) {
      guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
      self.id = id
      self.label = label
      self.value = value
    }
  }

  var body: some View {
    if !rows.isEmpty {
      VStack(spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
          if index > 0 {
            Divider().overlay(Color.fuelInk.opacity(0.06))
          }
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.label).fuelEyebrow()
            Spacer(minLength: 12)
            Text(row.value)
              .font(.fuelBody(.subheadline, weight: 500))
              .foregroundStyle(Color.fuelInk)
              .multilineTextAlignment(.trailing)
          }
          .padding(.vertical, 12)
        }
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .fuelCard()
    }
  }
}

// MARK: - Instructions

// The dataset's numbered how-to, as a numbered list. Blank steps are dropped
// before counting, so the numbers always run 1…n with no gaps.
struct ExerciseInstructionsSection: View {
  let steps: [String]
  /// Shown when nothing survives the filter — the two screens word it
  /// differently ("this exercise" vs "this workout").
  let emptyMessage: LocalizedStringKey

  private var cleanSteps: [String] {
    steps.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Instructions").fuelEyebrow()

      if cleanSteps.isEmpty {
        Text(emptyMessage)
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
      } else {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(Array(cleanSteps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .firstTextBaseline, spacing: 12) {
              Text("\(index + 1)")
                .font(.fuelMono(.footnote, weight: 600))
                .foregroundStyle(Color.fuelWorkoutInk)
                .frame(minWidth: 18, alignment: .leading)
              // Dataset content, English only — never routed through the
              // string catalog.
              Text(verbatim: step)
                .font(.fuelBody(.callout))
                .foregroundStyle(Color.fuelInk)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fuelCard()
      }
    }
  }
}
