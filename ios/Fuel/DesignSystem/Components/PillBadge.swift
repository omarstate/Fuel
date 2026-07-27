import SwiftUI

// A small status pill used for tags, provenance, streaks, pace labels.
struct PillBadge: View {
  enum Tone {
    case neutral
    case volt
    case citrus
    case gold
    case destructive

    var fill: Color {
      switch self {
      case .neutral: return Color.fuelSubtle.opacity(0.14)
      case .volt: return Color.fuelOlive.opacity(0.16)
      case .citrus: return Color.fuelCitrus.opacity(0.16)
      case .gold: return Color.fuelGold.opacity(0.18)
      case .destructive: return Color.fuelDestructive.opacity(0.14)
      }
    }

    var ink: Color {
      switch self {
      case .neutral: return .fuelSubtle
      case .volt: return .fuelVoltInk
      case .citrus: return .fuelCitrusInk
      case .gold: return .fuelGoldInk
      case .destructive: return .fuelDestructive
      }
    }
  }

  let title: LocalizedStringKey
  var systemImage: String?
  var tone: Tone = .neutral

  var body: some View {
    HStack(spacing: 4) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(.caption2.weight(.bold))
      }
      Text(title)
        .font(.fuelMono(.caption, weight: 600))
    }
    .foregroundStyle(tone.ink)
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(tone.fill, in: Capsule())
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 12) {
    PillBadge(title: "Official", systemImage: "checkmark.seal.fill", tone: .volt)
    PillBadge(title: "AI estimate", systemImage: "sparkles", tone: .citrus)
    PillBadge(title: "7 day streak", systemImage: "flame.fill", tone: .gold)
    PillBadge(title: "Over target", tone: .destructive)
    PillBadge(title: "Snack", tone: .neutral)
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
