import Foundation

// PURE Foundation port of the resize math in
// frontend/src/app-editorial/image-compress.ts. Kept separate from the UIKit
// pixel pipeline so the long-edge cap + aspect-ratio math is unit-tested without
// a graphics context. A ~4MB phone photo downscales to a few hundred KB, which
// keeps uploads fast and Gemini costs low — while staying ≥ ~1280px on the long
// edge so the label reader can still read thin text.
enum ImageResize {
  /// Long-edge cap, matching the web `MAX_EDGE`.
  static let maxEdge = 1280
  /// JPEG quality, matching the web `QUALITY`.
  static let quality: Double = 0.9
  /// Hard ceiling on base64 length, matching the backend validator
  /// (`MAX_IMAGE_BASE64_CHARS` ≈ 12MB of base64).
  static let maxBase64Chars = 12_000_000

  /// Fit dimensions under the long-edge cap, preserving aspect ratio. Images
  /// already within the cap are returned unchanged (mirrors the web `fit`).
  static func fit(width: Int, height: Int, maxEdge: Int = maxEdge) -> (width: Int, height: Int) {
    let longest = max(width, height)
    guard longest > maxEdge else { return (width, height) }
    let scale = Double(maxEdge) / Double(longest)
    return (
      width: Int((Double(width) * scale).rounded()),
      height: Int((Double(height) * scale).rounded())
    )
  }
}
