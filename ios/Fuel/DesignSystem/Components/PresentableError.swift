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

  /// Wrap for display — unless the error is a cancellation, which yields nil.
  /// Read paths driven by `.refreshable`/`.task` get cancelled as a matter of
  /// course (letting go of a pull, leaving the screen mid-load); that is not a
  /// failure the user can act on, so it must never reach a banner.
  static func presentable(_ error: Error) -> PresentableError? {
    isCancellation(error) ? nil : PresentableError(error)
  }

  static func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let urlError = error as? URLError, urlError.code == .cancelled { return true }
    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
  }

  static func == (lhs: PresentableError, rhs: PresentableError) -> Bool {
    lhs.id == rhs.id
  }
}
