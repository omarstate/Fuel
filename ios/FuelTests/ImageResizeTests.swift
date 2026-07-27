import Testing
import Foundation
@testable import Fuel

// The pure resize-dimension math behind the photo upload pipeline (the UIKit
// pixel work in ImageCompression is exercised on-device). Mirrors the web
// `fit`: cap the long edge at 1280 px, preserve aspect ratio, leave small
// images untouched.
@Suite("ImageResize")
struct ImageResizeTests {

  @Test("Long edge is capped and aspect ratio preserved (landscape)")
  func landscapeCapped() {
    let fit = ImageResize.fit(width: 4000, height: 3000)
    #expect(fit.width == 1280)
    #expect(fit.height == 960) // 3000 * (1280/4000)
  }

  @Test("Portrait caps the height, scales the width")
  func portraitCapped() {
    let fit = ImageResize.fit(width: 3000, height: 4000)
    #expect(fit.width == 960)
    #expect(fit.height == 1280)
  }

  @Test("Exact 2:1 scaling stays exact")
  func exactHalf() {
    let fit = ImageResize.fit(width: 2560, height: 1280)
    #expect(fit.width == 1280)
    #expect(fit.height == 640)
  }

  @Test("Images within the cap are returned unchanged")
  func smallUntouched() {
    let a = ImageResize.fit(width: 1000, height: 800)
    #expect(a.width == 1000 && a.height == 800)
    let b = ImageResize.fit(width: 1280, height: 1280)
    #expect(b.width == 1280 && b.height == 1280)
  }

  @Test("Square oversize scales both edges to the cap")
  func squareOversize() {
    let fit = ImageResize.fit(width: 3000, height: 3000)
    #expect(fit.width == 1280 && fit.height == 1280)
  }

  @Test("Base64 ceiling matches the backend validator")
  func base64Ceiling() {
    #expect(ImageResize.maxBase64Chars == 12_000_000)
  }
}
