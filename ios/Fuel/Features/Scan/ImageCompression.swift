import UIKit

// Downscale + JPEG-encode a picked photo before upload — the UIKit half of the
// pipeline whose dimension math lives (and is tested) in Core/Logic/ImageResize.
// Mirrors frontend/src/app-editorial/image-compress.ts: cap the long edge at
// 1280px, encode JPEG at 0.9, hand back RAW base64 (no data: prefix). If the
// result still exceeds the backend's base64 ceiling we re-encode at falling
// quality so a giant photo can't 413.
enum ImageCompression {
  struct Result: Sendable {
    /// Raw base64 (no data: prefix), for the API.
    let base64: String
    let mimeType: String
    /// A UIImage sized for an on-screen thumbnail preview.
    let preview: UIImage
  }

  enum CompressionError: LocalizedError {
    case tooLarge
    var errorDescription: String? {
      String(localized: "That photo is too large to process. Try a smaller one.")
    }
  }

  /// Steps to try if the first JPEG is over the base64 ceiling.
  private static let fallbackQualities: [Double] = [0.7, 0.5, 0.35]

  static func compress(_ image: UIImage) throws -> Result {
    let normalized = image.normalizedUp()
    let px = normalized.pixelSize
    let fit = ImageResize.fit(width: px.width, height: px.height)
    let target = CGSize(width: fit.width, height: fit.height)

    let resized = target == CGSize(width: px.width, height: px.height)
      ? normalized
      : normalized.redraw(to: target)

    // Encode at the primary quality, then step down only if needed.
    for quality in [ImageResize.quality] + fallbackQualities {
      guard let data = resized.jpegData(compressionQuality: quality) else { continue }
      let base64 = data.base64EncodedString()
      if base64.count <= ImageResize.maxBase64Chars {
        return Result(base64: base64, mimeType: "image/jpeg", preview: resized)
      }
    }
    throw CompressionError.tooLarge
  }
}

private extension UIImage {
  /// Pixel dimensions (points × scale), what the JPEG encoder actually writes.
  var pixelSize: (width: Int, height: Int) {
    (Int((size.width * scale).rounded()), Int((size.height * scale).rounded()))
  }

  /// Redraw into a 1× context of the given pixel size (also bakes in
  /// orientation). Uses UIGraphicsImageRenderer per the milestone.
  func redraw(to pixelSize: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: pixelSize))
    }
  }

  /// Bake EXIF orientation into an upright bitmap so portrait phone photos
  /// aren't logged sideways (mirrors the web's `imageOrientation: "from-image"`).
  func normalizedUp() -> UIImage {
    guard imageOrientation != .up else { return self }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = scale
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }
}
