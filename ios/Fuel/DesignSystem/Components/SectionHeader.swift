import SwiftUI

// A section header with an uppercase mono eyebrow, a Google Sans Flex title, and
// an optional trailing accessory (e.g. a "See all" button or count).
struct SectionHeader<Accessory: View>: View {
  let title: LocalizedStringKey
  var eyebrow: LocalizedStringKey?
  @ViewBuilder var accessory: () -> Accessory

  init(
    _ title: LocalizedStringKey,
    eyebrow: LocalizedStringKey? = nil,
    @ViewBuilder accessory: @escaping () -> Accessory
  ) {
    self.title = title
    self.eyebrow = eyebrow
    self.accessory = accessory
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        if let eyebrow {
          Text(eyebrow).fuelEyebrow()
        }
        Text(title)
          .font(.fuelTitle2)
          .foregroundStyle(Color.fuelInk)
      }
      Spacer(minLength: 12)
      accessory()
    }
  }
}

extension SectionHeader where Accessory == EmptyView {
  init(_ title: LocalizedStringKey, eyebrow: LocalizedStringKey? = nil) {
    self.title = title
    self.eyebrow = eyebrow
    self.accessory = { EmptyView() }
  }
}

#Preview {
  VStack(spacing: 24) {
    SectionHeader("Today", eyebrow: "Saturday, 19 July")
    SectionHeader("Your meals", eyebrow: "Logged") {
      Text("4").font(.fuelMetric).foregroundStyle(Color.fuelSubtle)
    }
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
