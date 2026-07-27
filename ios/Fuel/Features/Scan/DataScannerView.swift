import SwiftUI
import VisionKit
import AVFoundation

// UIViewControllerRepresentable wrapper around VisionKit's live barcode scanner.
// Recognizes the retail symbologies (EAN-13/EAN-8/UPC-E) and reports the first
// code back once. `isScanning` starts/stops recognition (we stop on a hit so the
// preview freezes while we look the code up); `torchOn` drives the flashlight on
// the shared capture device. Only ever instantiated when
// `DataScannerViewController.isSupported && .isAvailable`, so it never runs in
// the simulator.
struct DataScannerView: UIViewControllerRepresentable {
  @Binding var isScanning: Bool
  @Binding var torchOn: Bool
  var onScan: (String) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

  func makeUIViewController(context: Context) -> DataScannerViewController {
    let scanner = DataScannerViewController(
      recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
      qualityLevel: .balanced,
      recognizesMultipleItems: false,
      isHighFrameRateTrackingEnabled: true,
      isPinchToZoomEnabled: true,
      isGuidanceEnabled: false,
      isHighlightingEnabled: true
    )
    scanner.delegate = context.coordinator
    return scanner
  }

  func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
    context.coordinator.onScan = onScan
    if isScanning, !context.coordinator.isRunning {
      try? scanner.startScanning()
      context.coordinator.isRunning = true
    } else if !isScanning, context.coordinator.isRunning {
      scanner.stopScanning()
      context.coordinator.isRunning = false
    }
    CameraTorch.set(torchOn)
  }

  static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
    scanner.stopScanning()
    coordinator.isRunning = false
    CameraTorch.set(false)
  }

  final class Coordinator: NSObject, DataScannerViewControllerDelegate {
    var onScan: (String) -> Void
    var isRunning = false
    private var didReport = false

    init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
      report(from: addedItems)
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
      report(from: [item])
    }

    private func report(from items: [RecognizedItem]) {
      guard !didReport else { return }
      for case let .barcode(barcode) in items {
        guard let value = barcode.payloadStringValue, !value.isEmpty else { continue }
        didReport = true
        onScan(value)
        return
      }
    }
  }
}

// Best-effort torch control. DataScanner owns the capture session internally, so
// we toggle the flashlight on the same physical device. Silently no-ops when
// there's no torch (front camera, simulator, permission denied).
enum CameraTorch {
  static func set(_ on: Bool) {
    guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
    guard (try? device.lockForConfiguration()) != nil else { return }
    device.torchMode = on ? .on : .off
    device.unlockForConfiguration()
  }
}
