import SwiftUI

// Inline error banner with optional retry. Used for request failures and
// cold-start timeouts — sits on content, is not glass.
struct ErrorBanner: View {
  let error: PresentableError
  var onRetry: (() -> Void)?
  var onDismiss: (() -> Void)?

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: error.isRetryable ? "wifi.exclamationmark" : "exclamationmark.triangle.fill")
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color.fuelDestructive)
      VStack(alignment: .leading, spacing: 8) {
        Text(error.message)
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelInk)
          .fixedSize(horizontal: false, vertical: true)
        if let onRetry {
          Button("Try again", action: onRetry)
            .font(.fuelBody(.subheadline, weight: 600))
            .buttonStyle(.plain)
            .foregroundStyle(Color.fuelVoltInk)
        }
      }
      Spacer(minLength: 0)
      if let onDismiss {
        Button {
          onDismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.fuelSubtle)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss")
      }
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.fuelDestructive.opacity(0.10))
    )
  }
}

#Preview {
  VStack(spacing: 16) {
    ErrorBanner(
      error: PresentableError(message: "Couldn't reach the server. Check your connection and try again.", isRetryable: true),
      onRetry: {},
      onDismiss: {}
    )
    ErrorBanner(error: PresentableError(message: "Age must be between 13 and 120."))
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}
