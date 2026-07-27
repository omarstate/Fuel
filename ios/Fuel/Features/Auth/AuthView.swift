import SwiftUI

// First screen anyone sees. A single view that flips between sign-in and
// sign-up, plus a post-signup "check your email" confirmation state.
struct AuthView: View {
  @Environment(AppState.self) private var app

  private enum Mode { case signIn, signUp }
  private enum Field { case email, password }

  @State private var mode: Mode = .signIn
  @State private var email = ""
  @State private var password = ""
  @State private var error: PresentableError?
  @State private var confirmationSent = false
  @FocusState private var focus: Field?

  private var trimmedEmail: String {
    email.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var emailValid: Bool {
    let value = trimmedEmail
    return value.contains("@") && value.contains(".") && value.count >= 5
  }

  private var passwordValid: Bool { password.count >= 6 }
  private var formValid: Bool { emailValid && passwordValid }

  var body: some View {
    ZStack {
      Color.fuelBackground.ignoresSafeArea()

      ScrollView {
        VStack(spacing: 28) {
          header

          if confirmationSent {
            confirmationCard
          } else {
            formCard
          }
        }
        .padding(24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focus = nil }
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(spacing: 12) {
      Image("FuelLogo")
        .resizable()
        .scaledToFit()
        .frame(width: 76, height: 76)
        .accessibilityHidden(true)
      Text("Fuel")
        .font(.fuelHeading(46, weight: 700, relativeTo: .largeTitle))
        .foregroundStyle(Color.fuelInk)
      Text(mode == .signIn ? "Welcome back." : "Track smarter, Egypt-first.")
        .font(.fuelBody(.headline, weight: 600))
        .foregroundStyle(Color.fuelSubtle)
    }
    .padding(.top, 40)
  }

  // MARK: - Form

  private var formCard: some View {
    VStack(spacing: 18) {
      if let error {
        ErrorBanner(error: error, onDismiss: { self.error = nil })
      }

      VStack(spacing: 14) {
        TextField("Email", text: $email)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.next)
          .focused($focus, equals: .email)
          .onSubmit { focus = .password }
          .fieldStyle()

        SecureField("Password", text: $password)
          .textContentType(mode == .signIn ? .password : .newPassword)
          .submitLabel(.go)
          .focused($focus, equals: .password)
          .onSubmit { if formValid { Task { await submit() } } }
          .fieldStyle()

        if mode == .signUp && !password.isEmpty && !passwordValid {
          Text("Password must be at least 6 characters.")
            .font(.fuelBody(.caption))
            .foregroundStyle(Color.fuelDestructive)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      AsyncButton(mode == .signIn ? "Sign in" : "Create account") {
        await submit()
      }
      .disabled(!formValid)
      .frame(maxWidth: .infinity)
      .controlSize(.large)

      Button {
        withAnimation(.snappy) {
          mode = (mode == .signIn) ? .signUp : .signIn
          error = nil
        }
      } label: {
        Text(mode == .signIn ? "New here? Create an account" : "Already have an account? Sign in")
          .font(.fuelBody(.subheadline, weight: 500))
          .foregroundStyle(Color.fuelCitrusInk)
      }
      .buttonStyle(.plain)
      .padding(.top, 4)
    }
    .padding(22)
    .fuelCard()
  }

  private var confirmationCard: some View {
    VStack(spacing: 16) {
      Image(systemName: "envelope.badge.fill")
        .font(.system(size: 40))
        .foregroundStyle(Color.fuelCitrusInk)
      Text("Check your email")
        .font(.fuelTitle2)
        .foregroundStyle(Color.fuelInk)
      Text("We sent a confirmation link to \(trimmedEmail). Tap it, then come back and sign in.")
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
        .multilineTextAlignment(.center)
      Button("Back to sign in") {
        withAnimation(.snappy) {
          confirmationSent = false
          mode = .signIn
          password = ""
        }
      }
      .font(.fuelBody(.subheadline, weight: 600))
      .buttonStyle(.plain)
      .foregroundStyle(Color.fuelCitrusInk)
      .padding(.top, 4)
    }
    .padding(24)
    .frame(maxWidth: .infinity)
    .fuelCard()
  }

  // MARK: - Actions

  private func submit() async {
    focus = nil
    error = nil
    guard emailValid else {
      error = PresentableError(message: String(localized: "Enter a valid email address."))
      return
    }
    guard passwordValid else {
      error = PresentableError(message: String(localized: "Password must be at least 6 characters."))
      return
    }

    do {
      switch mode {
      case .signIn:
        try await SupabaseService.shared.signIn(email: trimmedEmail, password: password)
        // authStateChanges drives AppState from here.
      case .signUp:
        let outcome = try await SupabaseService.shared.signUp(email: trimmedEmail, password: password)
        if outcome == .confirmationRequired {
          withAnimation(.snappy) { confirmationSent = true }
        }
        // If .signedIn, authStateChanges drives AppState.
      }
    } catch {
      self.error = PresentableError(error)
    }
  }
}

// Shared field chrome for the auth form.
private struct FieldStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 14)
      .padding(.vertical, 13)
      .background(Color.fuelBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.fuelSubtle.opacity(0.18), lineWidth: 1)
      )
  }
}

private extension View {
  func fieldStyle() -> some View { modifier(FieldStyle()) }
}

#Preview {
  AuthView()
    .environment(AppState())
}
