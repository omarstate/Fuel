import SwiftUI

// A shared, presentable error wrapper so any thrown Error can be surfaced as
// friendly copy (via ErrorBanner or an alert) without leaking internals.
struct PresentableError: Identifiable, Equatable {
  let id = UUID()
  let message: String
  /// True when a cold-start retry banner is appropriate.
  let isRetryable: Bool

  init(_ error: Error) {
    if let apiError = error as? APIError {
      self.message = apiError.errorDescription ?? String(localized: "Something went wrong.")
      self.isRetryable = apiError.isTimeout || apiError == .network
    } else if let localized = error as? LocalizedError, let description = localized.errorDescription {
      self.message = description
      self.isRetryable = false
    } else {
      self.message = error.localizedDescription
      self.isRetryable = false
    }
  }

  init(message: String, isRetryable: Bool = false) {
    self.message = message
    self.isRetryable = isRetryable
  }

  static func == (lhs: PresentableError, rhs: PresentableError) -> Bool {
    lhs.id == rhs.id
  }
}
