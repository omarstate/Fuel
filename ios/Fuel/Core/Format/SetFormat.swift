import Foundation

// The one place that decides how a logged set's load reads, so the live pills,
// the history rows and the "last time" guidance can never disagree.
//
// The rules it encodes:
// - a nil weight is a BODYWEIGHT set — it reads "BW" (Arabic "وزن الجسم"),
//   never "—" and never 0 kg, both of which lie about the load;
// - a nil rep count simply drops the "× reps" half instead of rendering "× —";
// - only a set with neither value (possible via the editor clearing both)
//   falls back to a bare "—".
enum SetFormat {
  /// The localized bodyweight marker shown in place of a weight.
  static var bodyweight: String { String(localized: "BW") }

  /// The pill/row shape: "80 × 8", "BW × 12", "80", "BW".
  static func pair(weight: Double?, reps: Int?) -> String {
    joined(weight: weight, reps: reps, separator: " × ")
  }

  /// The tight shape for inline summaries ("last time" lines): "80×8", "BW×12".
  static func compact(weight: Double?, reps: Int?) -> String {
    joined(weight: weight, reps: reps, separator: "×")
  }

  /// What VoiceOver reads for a set's load — prose, not the "×" shorthand.
  static func accessibilityValue(weight: Double?, reps: Int?) -> String {
    switch (weight, reps) {
    case let (w?, r?):
      return String(localized: "\(DurationFormat.weight(w)) kilograms by \(String(r)) reps")
    case let (w?, nil):
      return String(localized: "\(DurationFormat.weight(w)) kilograms")
    case let (nil, r?):
      return String(localized: "Bodyweight, \(String(r)) reps")
    case (nil, nil):
      return "—"
    }
  }

  private static func joined(weight: Double?, reps: Int?, separator: String) -> String {
    guard weight != nil || reps != nil else { return "—" }
    let load = weight.map(DurationFormat.weight) ?? bodyweight
    guard let reps else { return load }
    return "\(load)\(separator)\(reps)"
  }
}
