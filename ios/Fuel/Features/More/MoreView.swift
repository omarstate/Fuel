import SwiftUI
import UIKit

// The More tab — the app's settings hub, replacing the old dedicated Profile
// tab. Layout is modeled on grouped-settings pages (Breadfast's More screen
// was the reference): the USER'S NAME as the masthead, a two-up strip of
// glanceable tiles (daily goal pulled out of the Profile details, plus the
// logging streak), then eyebrow-headed section cards where each card groups
// its rows with hairline separators. Account actions (sign out / delete) stay
// at the bottom, one deliberate tap away, with the app version as the footer.
struct MoreView: View {
  @Environment(AppState.self) private var app
  @Environment(\.openURL) private var openURL

  /// Days-in-a-row with anything logged, fetched lazily; nil while loading.
  @State private var loggingStreak: Int?

  @State private var showDeleteConfirm = false
  @State private var deleteConfirmText = ""
  @State private var deleteError: PresentableError?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          masthead
          tiles

          section("Food") {
            MoreGroup {
              NavigationLink { MyMealsView() } label: {
                MoreRow(icon: "book.closed.fill", tint: .fuelGoldInk, title: "My meals")
              }
              .buttonStyle(.plain)
            }
          }

          section("Account") {
            MoreGroup {
              NavigationLink { ProfileView() } label: {
                MoreRow(icon: "person.crop.circle.fill", tint: .fuelVoltInk, title: "Profile")
              }
              .buttonStyle(.plain)

              Divider().overlay(Color.fuelInk.opacity(0.06)).padding(.leading, 58)

              Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
              } label: {
                MoreRow(icon: "globe", tint: .fuelBlueInk, title: "Language") {
                  Text(currentLanguageName)
                    .font(.fuelBody(.subheadline))
                    .foregroundStyle(Color.fuelSubtle)
                }
              }
              .buttonStyle(.plain)
            }
          }

          signOutCard
          deleteAccountFooter
          versionFooter
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
      }
      .background(Color.fuelBackground.ignoresSafeArea())
      .scrollEdgeEffectStyle(.soft, for: .top)
      .toolbar(.hidden, for: .navigationBar)
      .statusBarFade()
      // Streak reflects the log; recompute when anything is logged/deleted.
      .task(id: app.logRevision) { await loadStreak() }
    }
  }

  // MARK: - Masthead (the user's name, not a generic "More")

  private var masthead: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(app.displayName ?? String(localized: "More"))
        .font(.fuelMasthead)
        .foregroundStyle(Color.fuelInk)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      if let email = app.me?.email {
        Text(email)
          .font(.fuelMono(.footnote))
          .foregroundStyle(Color.fuelSubtle)
      }
    }
  }

  // MARK: - Glanceable tiles (profile facts, surfaced)

  private var tiles: some View {
    HStack(spacing: 12) {
      // Tappable: goals are directly editable (PUT /profile/targets).
      NavigationLink { DailyGoalsView() } label: {
        StatTile(label: "Daily goal", value: app.targets.calories.formatted(), unit: "kcal",
                 systemImage: "target", tint: .fuelVoltInk)
      }
      .buttonStyle(.plain)
      StatTile(label: "Streak", value: loggingStreak.map(String.init) ?? "–", unit: "days",
               systemImage: "flame.fill", tint: .fuelGoldInk)
    }
  }

  /// Same computation History's streak pill uses; failures stay quiet (the
  /// tile just shows a dash — More must render fine offline).
  private func loadStreak() async {
    do {
      let perDay = try await MealLogRepository().dailyCalorieTotals()
      loggingStreak = Streaks.compute(perDayCalories: perDay, goalCalories: app.targets.calories).logging
    } catch {
      loggingStreak = loggingStreak ?? 0
    }
  }

  private func section(_ title: LocalizedStringKey, @ViewBuilder rows: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).fuelEyebrow()
      rows()
    }
  }

  private var currentLanguageName: String {
    let code = Locale.current.language.languageCode?.identifier ?? "en"
    return Locale(identifier: code).localizedString(forLanguageCode: code)?.capitalized ?? code
  }

  // MARK: - Account actions

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
    .padding(.top, 6)
  }

  // The quiet footer near the bottom: a compact destructive text button —
  // deliberately NOT full-width, outside any card.
  private var deleteAccountFooter: some View {
    VStack(spacing: 10) {
      if let deleteError {
        ErrorBanner(error: deleteError, onDismiss: { self.deleteError = nil })
      }
      // "Deactivate" is the label Omar wants on the entry point; the confirm
      // copy stays brutally honest that the action permanently deletes.
      Button(role: .destructive) {
        deleteConfirmText = ""
        showDeleteConfirm = true
      } label: {
        Text("Deactivate account")
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
    .alert("Deactivate account?", isPresented: $showDeleteConfirm) {
      TextField(String(localized: "Type \(deleteConfirmPhrase) to confirm"), text: $deleteConfirmText)
        .textInputAutocapitalization(.never)
      Button("Cancel", role: .cancel) {}
      Button("Deactivate", role: .destructive) {
        Task { await deleteAccount() }
      }
      .disabled(!deleteConfirmMatches)
    } message: {
      Text("This permanently deletes your account, profile and all logged meals. This cannot be undone. Type \"\(deleteConfirmPhrase)\" to confirm.")
    }
  }

  private var versionFooter: some View {
    Text("Fuel · Version \(appVersion)")
      .font(.fuelMono(.caption2))
      .foregroundStyle(Color.fuelSubtle)
      .frame(maxWidth: .infinity)
      .padding(.top, 2)
  }

  private var appVersion: String {
    let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "\(short) (\(build))"
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
}

// MARK: - Grouped card

// One card holding several rows (Breadfast-style): callers interleave rows
// with Dividers; the card supplies the surface.
private struct MoreGroup<Content: View>: View {
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(spacing: 0) {
      content()
    }
    .fuelCard()
  }
}

// MARK: - Row

// One tappable settings row: leading tinted icon, title, optional trailing
// value, chevron. Plain (no card) — MoreGroup provides the surface.
private struct MoreRow<Trailing: View>: View {
  let icon: String
  let tint: Color
  let title: LocalizedStringKey
  @ViewBuilder var trailing: () -> Trailing

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 28)
      Text(title)
        .font(.fuelBody(.body, weight: 500))
        .foregroundStyle(Color.fuelInk)
      Spacer(minLength: 8)
      trailing()
      Image(systemName: "chevron.forward")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.fuelSubtle)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .contentShape(.rect)
  }
}

extension MoreRow where Trailing == EmptyView {
  init(icon: String, tint: Color, title: LocalizedStringKey) {
    self.icon = icon
    self.tint = tint
    self.title = title
    self.trailing = { EmptyView() }
  }
}

#Preview {
  MoreView()
    .environment(AppState())
}
