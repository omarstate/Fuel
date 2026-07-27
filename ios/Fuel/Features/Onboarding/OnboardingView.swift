import SwiftUI

// Non-dismissible, full-screen onboarding shown when phase == .needsOnboarding.
// Welcome → details form with a live target preview → Save (PUT /profile).
struct OnboardingView: View {
  @Environment(AppState.self) private var app

  private enum Step: Int, CaseIterable { case welcome, details }
  @State private var step: Step = .welcome
  @State private var model = ProfileFormModel()
  @State private var error: PresentableError?

  var body: some View {
    ZStack {
      Color.fuelBackground.ignoresSafeArea()

      VStack(spacing: 0) {
        progressBar
          .padding(.horizontal, 24)
          .padding(.top, 12)

        switch step {
        case .welcome:
          welcomeStep
        case .details:
          detailsStep
        }
      }
    }
    // Blocking: no interactive dismiss even if presented in a sheet context.
    .interactiveDismissDisabled(true)
  }

  private var progressBar: some View {
    HStack(spacing: 6) {
      ForEach(Step.allCases, id: \.rawValue) { s in
        Capsule()
          .fill(s.rawValue <= step.rawValue ? Color.fuelCitrus : Color.fuelSubtle.opacity(0.2))
          .frame(height: 4)
          .animation(.snappy, value: step)
      }
    }
  }

  // MARK: - Welcome

  private var welcomeStep: some View {
    VStack(spacing: 20) {
      Spacer()
      Image("FuelLogo")
        .resizable()
        .scaledToFit()
        .frame(width: 88, height: 88)
        .accessibilityHidden(true)
      Text("Welcome to Fuel")
        .font(.fuelMasthead)
        .foregroundStyle(Color.fuelInk)
        .multilineTextAlignment(.center)
      Text("A few quick details and we'll compute your daily calorie and macro targets. You can change these anytime.")
        .font(.fuelBody(.body))
        .foregroundStyle(Color.fuelSubtle)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
      Spacer()
      Button {
        withAnimation(.snappy) { step = .details }
      } label: {
        Text("Get started")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.glassProminent)
      .tint(.fuelCitrus)
      .controlSize(.large)
      .padding(.horizontal, 24)
      .padding(.bottom, 24)
    }
  }

  // MARK: - Details

  private var detailsStep: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 22) {
          VStack(alignment: .leading, spacing: 4) {
            Text("About you").fuelEyebrow()
            Text("Your details")
              .font(.fuelTitle)
              .foregroundStyle(Color.fuelInk)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          if let error {
            ErrorBanner(error: error, onDismiss: { self.error = nil })
          }

          ProfileFormFields(model: model)

          if let targets = model.previewTargets {
            TargetPreviewCard(targets: targets, direction: model.direction)
              .transition(.opacity.combined(with: .move(edge: .bottom)))
          }
        }
        .padding(24)
      }

      VStack(spacing: 10) {
        AsyncButton("Save & continue", successHaptic: true) {
          try await save()
        } onError: { err in
          error = PresentableError(err)
        }
        .disabled(!model.isValid)
        .frame(maxWidth: .infinity)
        .controlSize(.large)

        Button("Back") {
          withAnimation(.snappy) { step = .welcome }
        }
        .font(.fuelBody(.subheadline, weight: 500))
        .buttonStyle(.plain)
        .foregroundStyle(Color.fuelSubtle)
      }
      .padding(24)
      .background(
        Color.fuelBackground
          .overlay(alignment: .top) {
            Rectangle()
              .fill(Color.fuelSubtle.opacity(0.15))
              .frame(height: 1)
          }
      )
    }
  }

  private func save() async throws {
    error = nil
    guard let input = model.profileInput else {
      throw APIError.server(message: String(localized: "Please complete all fields."), status: 400)
    }
    let profile = try await FuelAPI.saveProfile(input)
    app.applyProfile(profile)
  }
}

#Preview {
  OnboardingView()
    .environment(AppState())
}
