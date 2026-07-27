import Foundation

// Shared JSON coding configuration for the Fuel API. Kept in one place so the
// APIClient and the decoding tests use identical settings. JSON is camelCase
// (no key strategy needed); dates decode ISO8601 with-and-without fractional
// seconds.
extension JSONDecoder {
  static func fuel() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let raw = try container.decode(String.self)
      if let date = ISO8601DateFormatter.fuelWithFractional.date(from: raw) {
        return date
      }
      if let date = ISO8601DateFormatter.fuelPlain.date(from: raw) {
        return date
      }
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unrecognized date format: \(raw)"
      )
    }
    return decoder
  }
}

extension ISO8601DateFormatter {
  static let fuelWithFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  static let fuelPlain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()
}
