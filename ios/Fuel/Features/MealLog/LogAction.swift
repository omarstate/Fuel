import SwiftUI

// The secondary log actions in the Today floating toolbar (the primary action is
// a plain manual add). Each carries its own accessibility title and SF Symbol.
// All are real flows; `voice` is the hero — speak a meal in Egyptian Arabic or
// English and it parses, matches the catalog, and logs.
enum LogAction: String, Identifiable {
  case voice
  case estimate
  case lookup
  case photo
  case barcode

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .voice: return "Voice log"
    case .estimate: return "AI estimate"
    case .lookup: return "AI lookup"
    case .photo: return "Photo label"
    case .barcode: return "Barcode scan"
    }
  }

  var systemImage: String {
    switch self {
    case .voice: return "waveform"
    case .estimate: return "sparkles"
    case .lookup: return "magnifyingglass"
    case .photo: return "camera"
    case .barcode: return "barcode.viewfinder"
    }
  }
}
