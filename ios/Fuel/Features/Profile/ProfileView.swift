import SwiftUI
import UIKit

// The Profile tab. Every section is a self-contained card: current daily
// targets, the editable BMR details (read-only until Edit), personal data
// (name / email / password, read-only until Edit), and account actions.
struct ProfileView: View {
  @Environment(AppState.self) private var app

  var body: some View {
    NavigationStack {
      Group {
        if let profile = app.profile {
          ProfileEditor(profile: profile)
        } else {
          ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .background(Color.fuelBackground)
      .navigationTitle("Profile")
      .navigationBarTitleDisplayMode(.large)
    }
  }
}

// MARK: - Card container

// A flat content card with an eyebrow + title header and an optional trailing
// accessory (e.g. an Edit button). One consistent treatment for every section.
private struct ProfileCard<Trailing: View, Content: View>: View {
  let eyebrow: LocalizedStringKey
  let title: LocalizedStringKey
  @ViewBuilder var trailing: () -> Trailing
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(eyebrow).fuelEyebrow()
          Text(title)
            .font(.fuelTitle2)
            .foregroundStyle(Color.fuelInk)
        }
        Spacer(minLength: 12)
        trailing()
      }
      content()
    }
    .padding(20)
    .fuelCard()
  }
}

extension ProfileCard where Trailing == EmptyView {
  init(
    eyebrow: LocalizedStringKey,
    title: LocalizedStringKey,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.eyebrow = eyebrow
    self.title = title
    self.trailing = { EmptyView() }
    self.content = content
  }
}

// A small glass "Edit" affordance for a card header.
private struct EditButton: View {
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Label("Edit", systemImage: "pencil")
        .font(.fuelBody(.subheadline, weight: 600))
    }
    .buttonStyle(.glass)
    .controlSize(.small)
    .tint(.fuelCitrus)
  }
}

// A read-only "label … value" row used inside cards.
private struct ReadOnlyRow: View {
  let label: LocalizedStringKey
  let value: String
  var mono = false

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .font(.fuelBody(.subheadline, weight: 500))
        .foregroundStyle(Color.fuelInk)
      Spacer(minLength: 12)
      Text(value)
        .font(mono ? .fuelMono(.subheadline) : .fuelBody(.subheadline, weight: 500))
        .foregroundStyle(Color.fuelInk)
        .multilineTextAlignment(.trailing)
    }
  }
}

// MARK: - Editor

private struct ProfileEditor: View {
  @Environment(AppState.self) private var app
  @Environment(\.openURL) private var openURL

  let profile: Profile

  // Details card
  @State private var model: ProfileFormModel
  @State private var editingDetails = false
  @State private var detailsError: PresentableError?

  // Personal data card
  @State private var editingPersonal = false
  @State private var nameText = ""
  @State private var newPassword = ""
  @State private var confirmPassword = ""
  @State private var personalError: PresentableError?
  @FocusState private var personalFocus: PersonalField?
  private enum PersonalField: Hashable { case name, password, confirm }

  // Account / danger
  @State private var showDeleteConfirm = false
  @State private var deleteConfirmText = ""
  @State private var deleteError: PresentableError?

  init(profile: Profile) {
    self.profile = profile
    _model = State(initialValue: ProfileFormModel(profile: profile))
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        targetsCard
        detailsCard
        personalCard
        preferencesCard
        signOutCard
        deleteAccountFooter
      }
      .padding(20)
    }
    .scrollDismissesKeyboard(.interactively)
  }

  // MARK: - Daily targets

  private var targetsCard: some View {
    ProfileCard(eyebrow: "Current", title: "Daily targets") {
      VStack(spacing: 16) {
        HStack(spacing: 16) {
          targetCell("Calories", app.targets.calories.formatted(), "kcal", tint: .fuelVoltInk)
          targetCell("Protein", app.targets.protein.formatted(), "g", tint: .fuelBlueInk)
        }
        HStack(spacing: 16) {
          targetCell("Carbs", app.targets.carbs.formatted(), "g", tint: .fuelGoldInk)
          targetCell("Fat", app.targets.fat.formatted(), "g", tint: .fuelVoltInk)
        }
      }
    }
  }

  private func targetCell(_ label: LocalizedStringKey, _ value: String, _ unit: LocalizedStringKey, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 5) {
        Circle()
          .fill(tint)
          .frame(width: 6, height: 6)
        Text(label).fuelEyebrow()
      }
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value)
          .font(.fuelMetric)
          .foregroundStyle(Color.fuelInk)
          .contentTransition(.numericText())
        Text(unit)
          .font(.fuelMono(.caption, weight: 600))
          .foregroundStyle(Color.fuelSubtle)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Details (BMR form)

  @ViewBuilder
  private var detailsCard: some View {
    if editingDetails {
      editableDetailsCard
    } else {
      readOnlyDetailsCard
    }
  }

  private var readOnlyDetailsCard: some View {
    ProfileCard(eyebrow: "Your info", title: "Your details") {
      EditButton { beginEditingDetails() }
    } content: {
      VStack(spacing: 12) {
        ReadOnlyRow(label: "Sex", value: sexLabel(profile.sex))
        ReadOnlyRow(label: "Age", value: "\(profile.age) yrs", mono: true)
        ReadOnlyRow(label: "Height", value: "\(trimmed(profile.heightCm)) cm", mono: true)
        ReadOnlyRow(label: "Weight", value: "\(trimmed(profile.weightKg)) kg", mono: true)
        ReadOnlyRow(label: "Goal weight", value: "\(trimmed(profile.goalWeightKg)) kg", mono: true)
        ReadOnlyRow(label: "Activity level", value: profile.activityLevel.label)
        ReadOnlyRow(label: "Pace", value: profile.pace.label)
      }
    }
  }

  private var editableDetailsCard: some View {
    ProfileCard(eyebrow: "Your info", title: "Edit details") {
      VStack(spacing: 16) {
        if let detailsError {
          ErrorBanner(error: detailsError, onDismiss: { self.detailsError = nil })
        }

        ProfileFormFields(model: model)

        if let targets = model.previewTargets {
          TargetPreviewCard(targets: targets, direction: model.direction, title: "New targets")
            .transition(.opacity)
        }

        VStack(spacing: 10) {
          AsyncButton("Save changes", successHaptic: true) {
            try await saveDetails()
          } onError: { err in
            detailsError = PresentableError(err)
          }
          .disabled(!model.isValid)
          .frame(maxWidth: .infinity)
          .controlSize(.large)

          Button("Cancel") { cancelEditingDetails() }
            .font(.fuelBody(.subheadline, weight: 500))
            .buttonStyle(.plain)
            .foregroundStyle(Color.fuelSubtle)
        }
      }
    }
  }

  private func beginEditingDetails() {
    model = ProfileFormModel(profile: profile)
    detailsError = nil
    withAnimation(.snappy) { editingDetails = true }
  }

  private func cancelEditingDetails() {
    detailsError = nil
    withAnimation(.snappy) { editingDetails = false }
  }

  private func saveDetails() async throws {
    detailsError = nil
    guard let input = model.profileInput else {
      throw APIError.server(message: String(localized: "Please complete all fields."), status: 400)
    }
    let saved = try await FuelAPI.saveProfile(input)
    app.applyProfile(saved)
    withAnimation(.snappy) { editingDetails = false }
  }

  // MARK: - Personal data

  @ViewBuilder
  private var personalCard: some View {
    if editingPersonal {
      editablePersonalCard
    } else {
      readOnlyPersonalCard
    }
  }

  private var readOnlyPersonalCard: some View {
    ProfileCard(eyebrow: "Account", title: "Personal data") {
      EditButton { beginEditingPersonal() }
    } content: {
      VStack(spacing: 12) {
        ReadOnlyRow(label: "Name", value: app.displayName ?? String(localized: "Not set"))
        ReadOnlyRow(label: "Email", value: app.me?.email ?? SupabaseService.shared.currentEmail ?? "—")
        ReadOnlyRow(label: "Password", value: "••••••••", mono: true)
      }
    }
  }

  private var editablePersonalCard: some View {
    ProfileCard(eyebrow: "Account", title: "Edit personal data") {
      VStack(alignment: .leading, spacing: 16) {
        if let personalError {
          ErrorBanner(error: personalError, onDismiss: { self.personalError = nil })
        }

        // Name
        VStack(alignment: .leading, spacing: 6) {
          Text("Name")
            .font(.fuelBody(.subheadline, weight: 500))
            .foregroundStyle(Color.fuelInk)
          TextField("Your name", text: $nameText)
            .textContentType(.name)
            .font(.fuelBody(.body))
            .focused($personalFocus, equals: .name)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .fieldBox()
        }

        // Email (read-only)
        VStack(alignment: .leading, spacing: 6) {
          Text("Email")
            .font(.fuelBody(.subheadline, weight: 500))
            .foregroundStyle(Color.fuelInk)
          Text(app.me?.email ?? SupabaseService.shared.currentEmail ?? "—")
            .font(.fuelMono(.subheadline))
            .foregroundStyle(Color.fuelSubtle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .fieldBox()
          Text("Email changes aren't supported yet.")
            .font(.fuelBody(.caption))
            .foregroundStyle(Color.fuelSubtle)
        }

        // Change password
        VStack(alignment: .leading, spacing: 6) {
          Text("Change password")
            .font(.fuelBody(.subheadline, weight: 500))
            .foregroundStyle(Color.fuelInk)
          SecureField("New password", text: $newPassword)
            .textContentType(.newPassword)
            .font(.fuelBody(.body))
            .focused($personalFocus, equals: .password)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .fieldBox()
          SecureField("Confirm new password", text: $confirmPassword)
            .textContentType(.newPassword)
            .font(.fuelBody(.body))
            .focused($personalFocus, equals: .confirm)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .fieldBox()
          if let hint = passwordHint {
            Text(hint)
              .font(.fuelBody(.caption))
              .foregroundStyle(Color.fuelDestructive)
          } else {
            Text("Leave blank to keep your current password. Minimum 6 characters.")
              .font(.fuelBody(.caption))
              .foregroundStyle(Color.fuelSubtle)
          }
        }

        VStack(spacing: 10) {
          AsyncButton("Save changes", successHaptic: true) {
            try await savePersonal()
          } onError: { err in
            personalError = PresentableError(err)
          }
          .disabled(!personalCanSave)
          .frame(maxWidth: .infinity)
          .controlSize(.large)

          Button("Cancel") { cancelEditingPersonal() }
            .font(.fuelBody(.subheadline, weight: 500))
            .buttonStyle(.plain)
            .foregroundStyle(Color.fuelSubtle)
        }
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { personalFocus = nil }
      }
    }
  }

  private var trimmedName: String { nameText.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var nameChanged: Bool { trimmedName != (app.displayName ?? "") && !trimmedName.isEmpty }
  private var passwordEntered: Bool { !newPassword.isEmpty || !confirmPassword.isEmpty }
  private var passwordValid: Bool { newPassword.count >= 6 && newPassword == confirmPassword }

  private var passwordHint: LocalizedStringKey? {
    guard passwordEntered else { return nil }
    if newPassword.count < 6 { return "Password must be at least 6 characters." }
    if newPassword != confirmPassword { return "Passwords don't match." }
    return nil
  }

  private var personalCanSave: Bool {
    if passwordEntered && !passwordValid { return false }
    return nameChanged || (passwordEntered && passwordValid)
  }

  private func beginEditingPersonal() {
    nameText = app.displayName ?? ""
    newPassword = ""
    confirmPassword = ""
    personalError = nil
    withAnimation(.snappy) { editingPersonal = true }
  }

  private func cancelEditingPersonal() {
    personalError = nil
    personalFocus = nil
    withAnimation(.snappy) { editingPersonal = false }
  }

  private func savePersonal() async throws {
    personalError = nil
    if nameChanged {
      try await SupabaseService.shared.updateDisplayName(trimmedName)
      app.applyDisplayName(trimmedName)
    }
    if passwordEntered {
      guard passwordValid else {
        throw APIError.server(message: String(localized: "Please fix the password fields."), status: 400)
      }
      try await SupabaseService.shared.updatePassword(newPassword)
    }
    newPassword = ""
    confirmPassword = ""
    personalFocus = nil
    withAnimation(.snappy) { editingPersonal = false }
  }

  // MARK: - Account / danger zone

  private var currentLanguageName: String {
    let code = Locale.current.language.languageCode?.identifier ?? "en"
    return Locale(identifier: code).localizedString(forLanguageCode: code)?.capitalized ?? code
  }

  // Language lives in its own Preferences card — not lumped under "Account".
  private var preferencesCard: some View {
    ProfileCard(eyebrow: "App", title: "Preferences") {
      VStack(alignment: .leading, spacing: 8) {
        Button {
          if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "globe")
              .foregroundStyle(Color.fuelCitrusInk)
            Text("Language")
              .foregroundStyle(Color.fuelInk)
            Spacer()
            Text(currentLanguageName)
              .foregroundStyle(Color.fuelSubtle)
            Image(systemName: "chevron.forward")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(Color.fuelSubtle)
          }
          .font(.fuelBody(.subheadline, weight: 500))
          .padding(.vertical, 6)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Text("Switch the app language in Settings. Fuel is available in English and Arabic.")
          .font(.fuelBody(.caption))
          .foregroundStyle(Color.fuelSubtle)
      }
    }
  }

  // A Settings-style card row: red sign-out, full-width tappable, no pill.
  private var signOutCard: some View {
    AsyncButton(style: .plain, action: { await app.signOut() }) {
      Text("Sign out")
        .font(.fuelBody(.body, weight: 600))
        .foregroundStyle(Color.fuelDestructive)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
    .fuelCard()
  }

  // The quiet footer at the very bottom: a compact destructive text button —
  // deliberately NOT full-width, outside any card.
  private var deleteAccountFooter: some View {
    VStack(spacing: 10) {
      if let deleteError {
        ErrorBanner(error: deleteError, onDismiss: { self.deleteError = nil })
      }
      Button(role: .destructive) {
        deleteConfirmText = ""
        showDeleteConfirm = true
      } label: {
        Text("Delete account")
          .font(.fuelBody(.footnote, weight: 600))
          .foregroundStyle(Color.fuelDestructive)
          .padding(.horizontal, 18)
          .padding(.vertical, 10)
      }
      .buttonStyle(.plain)
      Text("Permanently removes your account and all data.")
        .font(.fuelBody(.caption2))
        .foregroundStyle(Color.fuelSubtle)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 4)
    .padding(.bottom, 12)
    .alert("Delete account?", isPresented: $showDeleteConfirm) {
      TextField(String(localized: "Type \(deleteConfirmPhrase) to confirm"), text: $deleteConfirmText)
        .textInputAutocapitalization(.never)
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        Task { await deleteAccount() }
      }
      .disabled(!deleteConfirmMatches)
    } message: {
      Text("This permanently deletes your account, profile and all logged meals. This cannot be undone. Type \"\(deleteConfirmPhrase)\" to confirm.")
    }
  }

  // Type-your-name confirmation: the display name when set, otherwise the
  // account email — always something the owner knows and a stranger might not.
  private var deleteConfirmPhrase: String {
    if let name = app.displayName, !name.isEmpty { return name }
    return app.me?.email ?? "DELETE"
  }

  private var deleteConfirmMatches: Bool {
    deleteConfirmText.trimmingCharacters(in: .whitespacesAndNewlines)
      .compare(deleteConfirmPhrase, options: [.caseInsensitive]) == .orderedSame
  }

  private func deleteAccount() async {
    guard deleteConfirmMatches else { return }
    do {
      try await FuelAPI.deleteAccount()
      await app.handleAccountDeleted()
    } catch {
      deleteError = PresentableError(error)
    }
  }

  // MARK: - Helpers

  private func sexLabel(_ sex: Sex) -> String {
    switch sex {
    case .male: return String(localized: "Male")
    case .female: return String(localized: "Female")
    }
  }

  private func trimmed(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
  }
}

// A shared input-box chrome for the personal-data text fields.
private extension View {
  func fieldBox() -> some View {
    background(Color.fuelSurface, in: RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
          .strokeBorder(Color.fuelInk.opacity(0.12), lineWidth: 1)
      )
  }
}

#Preview {
  ProfileView()
    .environment(AppState())
}
