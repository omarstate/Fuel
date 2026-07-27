import SwiftUI

// Shared editable profile form used by onboarding and the profile tab's details
// card (edit mode). Purely the inputs — the surrounding chrome (steps, save
// button, live preview) is the caller's.
//
// Layout: every input is a single row with its label on the leading edge.
// Numeric values use a compact, fixed-width trailing field (not full width);
// sex and activity level use trailing Menu pickers; pace is a row of generous,
// thumb-friendly buttons.
struct ProfileFormFields: View {
  @Bindable var model: ProfileFormModel

  private enum Field: Hashable { case age, height, weight, goal }
  @FocusState private var focus: Field?

  var body: some View {
    VStack(spacing: 14) {
      sexRow
      Divider().overlay(Color.fuelInk.opacity(0.06))
      numericRow(
        title: "Age", unit: "yrs", text: $model.ageText,
        field: .age, next: .height, error: model.ageError
      )
      numericRow(
        title: "Height", unit: "cm", text: $model.heightText,
        field: .height, next: .weight, error: model.heightError
      )
      numericRow(
        title: "Weight", unit: "kg", text: $model.weightText,
        field: .weight, next: .goal, error: model.weightError
      )
      numericRow(
        title: "Goal weight", unit: "kg", text: $model.goalText,
        field: .goal, next: nil, error: model.goalError
      )
      Divider().overlay(Color.fuelInk.opacity(0.06))
      activityRow
      paceSection
    }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focus = nil }
      }
    }
  }

  // MARK: - Sex

  private var sexRow: some View {
    HStack {
      Text("Sex")
        .font(.fuelBody(.subheadline, weight: 500))
        .foregroundStyle(Color.fuelInk)
      Spacer()
      Menu {
        Picker("Sex", selection: $model.sex) {
          Text("Male").tag(Sex.male)
          Text("Female").tag(Sex.female)
        }
      } label: {
        menuLabel(model.sex == .male ? String(localized: "Male") : String(localized: "Female"))
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Activity

  private var activityRow: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Activity level")
          .font(.fuelBody(.subheadline, weight: 500))
          .foregroundStyle(Color.fuelInk)
        Spacer()
        Menu {
          Picker("Activity level", selection: $model.activityLevel) {
            ForEach(ActivityLevel.allCases, id: \.self) { level in
              Text(level.label).tag(level)
            }
          }
        } label: {
          menuLabel(model.activityLevel.label)
        }
        .buttonStyle(.plain)
      }
      Text(model.activityLevel.hint)
        .font(.fuelBody(.caption))
        .foregroundStyle(Color.fuelSubtle)
    }
  }

  // MARK: - Pace

  private var paceSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Pace")
        .font(.fuelBody(.subheadline, weight: 500))
        .foregroundStyle(Color.fuelInk)
      HStack(spacing: 8) {
        ForEach(Pace.allCases, id: \.self) { pace in
          paceButton(pace)
        }
      }
      Text(paceCaption)
        .font(.fuelBody(.caption))
        .foregroundStyle(Color.fuelSubtle)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func paceButton(_ pace: Pace) -> some View {
    let selected = model.pace == pace
    return Button {
      withAnimation(.snappy) { model.pace = pace }
    } label: {
      VStack(spacing: 3) {
        Text(pace.label)
          .font(.fuelBody(.subheadline, weight: 600))
        Text(pace.hint)
          .font(.fuelMono(.caption2, weight: 500))
      }
      .frame(maxWidth: .infinity, minHeight: 56)
      .padding(.vertical, 6)
      .foregroundStyle(selected ? Color.fuelBackground : Color.fuelInk)
      .background(
        RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
          .fill(selected ? Color.fuelVolt : Color.fuelSurface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
          .strokeBorder(selected ? Color.clear : Color.fuelInk.opacity(0.12), lineWidth: 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var paceCaption: String {
    let magnitude = Int(model.pace.magnitude)
    switch model.direction {
    case .cut:
      return String(localized: "\(model.pace.hint) · −\(magnitude) kcal/day")
    case .bulk:
      return String(localized: "\(model.pace.hint) · +\(magnitude) kcal/day")
    case .maintain, .none:
      return String(localized: "Maintaining — pace applies once you set a goal weight.")
    }
  }

  // MARK: - Building blocks

  private func numericRow(
    title: LocalizedStringKey,
    unit: String,
    text: Binding<String>,
    field: Field,
    next: Field?,
    error: String?
  ) -> some View {
    VStack(alignment: .trailing, spacing: 6) {
      HStack {
        Text(title)
          .font(.fuelBody(.subheadline, weight: 500))
          .foregroundStyle(Color.fuelInk)
        Spacer()
        HStack(spacing: 6) {
          TextField("0", text: text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.fuelMono(.body))
            .foregroundStyle(Color.fuelInk)
            .focused($focus, equals: field)
            .submitLabel(next == nil ? .done : .next)
          Text(unit)
            .font(.fuelMono(.subheadline))
            .foregroundStyle(Color.fuelSubtle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 108)
        .background(Color.fuelSurface, in: RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
            .strokeBorder((error != nil) ? Color.fuelDestructive.opacity(0.6) : Color.fuelInk.opacity(0.12), lineWidth: 1)
        )
      }
      if let error {
        Text(error)
          .font(.fuelBody(.caption))
          .foregroundStyle(Color.fuelDestructive)
      }
    }
  }

  private func menuLabel(_ text: String) -> some View {
    HStack(spacing: 6) {
      Text(text)
        .font(.fuelBody(.subheadline, weight: 500))
        .foregroundStyle(Color.fuelInk)
      Image(systemName: "chevron.up.chevron.down")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color.fuelSubtle)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .background(Color.fuelSurface, in: RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
        .strokeBorder(Color.fuelInk.opacity(0.12), lineWidth: 1)
    )
    .contentShape(Rectangle())
  }
}

#Preview {
  ScrollView {
    ProfileFormFields(model: ProfileFormModel())
      .padding()
  }
  .background(Color.fuelBackground)
}
