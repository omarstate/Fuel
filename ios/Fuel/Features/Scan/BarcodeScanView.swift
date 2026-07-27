import SwiftUI
import VisionKit
import AVFoundation

// Full-screen barcode flow. On a capable device with camera permission it shows
// the live VisionKit scanner under a Liquid-Glass overlay (reticle, torch,
// cancel, "type the code"); on the first hit it stops, looks the code up via
// Open Food Facts, and routes into the shared review sheet. Simulator /
// unsupported / permission-denied fall back cleanly to manual code entry.
// Soft states (not found, no macros) and outages each get a designed screen with
// a manual-entry escape hatch, and a "scan again" affordance closes the loop.
struct BarcodeScanView: View {
  @Environment(\.dismiss) private var dismiss

  @State private var stage: Stage = .initializing
  @State private var cameraReady = false
  @State private var isScanning = false
  @State private var torchOn = false
  @State private var manualCode = ""
  @State private var reviewContext: LabelReviewContext?
  @State private var didLogFromReview = false
  @FocusState private var codeFieldFocused: Bool

  private enum Stage: Equatable {
    case initializing
    case scanning
    case lookingUp(code: String)
    case manualEntry(reason: FallbackReason?)
    case notFound(code: String)
    case failed(PresentableError, code: String?)
    case logged
  }

  enum FallbackReason: Equatable {
    case unsupported
    case denied

    var message: LocalizedStringKey {
      switch self {
      case .unsupported:
        return "Live scanning isn't available on this device. Enter the barcode digits printed under the barcode instead."
      case .denied:
        return "Camera access is off. Turn it on in Settings to scan, or enter the barcode digits printed under the barcode."
      }
    }
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if cameraReady, isCameraStage {
        DataScannerView(isScanning: $isScanning, torchOn: $torchOn) { code in
          handleScan(code)
        }
        .ignoresSafeArea()
      }

      overlay
    }
    .task { await setUp() }
    .sheet(item: $reviewContext, onDismiss: handleReviewDismiss) { ctx in
      LabelReviewSheet(review: ctx.review, brand: ctx.brand) {
        didLogFromReview = true
      }
    }
  }

  private var isCameraStage: Bool {
    switch stage {
    case .scanning, .lookingUp: return true
    default: return false
    }
  }

  // MARK: - Overlay router

  @ViewBuilder
  private var overlay: some View {
    switch stage {
    case .initializing:
      ProgressView()
        .controlSize(.large)
        .tint(.white)
    case .scanning:
      scannerOverlay(loading: nil)
    case let .lookingUp(code):
      scannerOverlay(loading: code)
    case let .manualEntry(reason):
      manualEntryScreen(reason: reason)
    case let .notFound(code):
      softStateScreen(
        icon: "barcode.viewfinder",
        title: "Product not found",
        message: "\(code) isn't in the barcode database yet. Enter its details by hand, or snap the nutrition label instead.",
        code: code
      )
    case let .failed(error, code):
      failureScreen(error: error, code: code)
    case .logged:
      loggedScreen
    }
  }

  // MARK: - Scanner overlay (glass, floating layer)

  private func scannerOverlay(loading code: String?) -> some View {
    VStack {
      GlassEffectContainer(spacing: 10) {
        HStack {
          glassIcon("xmark", label: "Cancel") { dismiss() }
          Spacer()
          if cameraReady, code == nil {
            glassIcon(torchOn ? "bolt.fill" : "bolt.slash", label: "Torch") {
              torchOn.toggle()
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)

      Spacer()

      reticle(active: code == nil)

      if let code {
        loadingCard(code: code)
          .padding(.top, 24)
      } else {
        Text("Point at a product barcode")
          .font(.fuelBody(.subheadline, weight: 500))
          .foregroundStyle(.white)
          .padding(.top, 20)
          .shadow(radius: 6)
      }

      Spacer()

      Button {
        openManualEntry()
      } label: {
        Label("Type the code", systemImage: "keyboard")
          .font(.fuelBody(.subheadline, weight: 600))
          .padding(.vertical, 4)
          .padding(.horizontal, 10)
      }
      .buttonStyle(.glass)
      .tint(.white)
      .padding(.bottom, 24)
      .opacity(code == nil ? 1 : 0)
    }
  }

  private func reticle(active: Bool) -> some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
      .strokeBorder(active ? Color.fuelVolt : Color.white.opacity(0.5), lineWidth: 3)
      .frame(width: 260, height: 170)
      .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(Color.white.opacity(0.06))
      )
      .shadow(color: .black.opacity(0.35), radius: 12)
      .overlay(alignment: .center) {
        if active {
          Image(systemName: "barcode")
            .font(.system(size: 40, weight: .regular))
            .foregroundStyle(.white.opacity(0.55))
        }
      }
  }

  private func loadingCard(code: String) -> some View {
    VStack(spacing: 10) {
      ProgressView().controlSize(.large).tint(.white)
      Text("Looking up \(code)…")
        .font(.fuelBody(.subheadline, weight: 500))
        .foregroundStyle(.white)
    }
    .padding(20)
    .glassEffect(in: .rect(cornerRadius: 18))
  }

  private func glassIcon(_ systemName: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.body.weight(.semibold))
        .frame(width: 30, height: 30)
    }
    .buttonStyle(.glass)
    .tint(.white)
    .accessibilityLabel(label)
  }

  // MARK: - Manual entry / soft states (content, on FuelBackground)

  private func manualEntryScreen(reason: FallbackReason?) -> some View {
    contentScaffold {
      VStack(spacing: 18) {
        Image(systemName: "barcode.viewfinder")
          .font(.system(size: 40))
          .foregroundStyle(Color.fuelVoltInk)
        Text("Enter barcode")
          .font(.fuelTitle2)
          .foregroundStyle(Color.fuelInk)
        if let reason {
          Text(reason.message)
            .font(.fuelBody(.subheadline))
            .foregroundStyle(Color.fuelSubtle)
            .multilineTextAlignment(.center)
        } else {
          Text("Type the 8–14 digit number printed beneath the barcode.")
            .font(.fuelBody(.subheadline))
            .foregroundStyle(Color.fuelSubtle)
            .multilineTextAlignment(.center)
        }

        TextField("e.g. 6224000123456", text: $manualCode)
          .keyboardType(.numberPad)
          .multilineTextAlignment(.center)
          .font(.fuelMono(.title3))
          .focused($codeFieldFocused)
          .padding(.vertical, 12)
          .padding(.horizontal, 16)
          .background(Color.fuelSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        Button {
          look(up: BarcodeCode.normalized(manualCode))
        } label: {
          Text("Look up").frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .tint(.fuelCitrus)
        .disabled(!BarcodeCode.isValid(manualCode))

        if cameraReady {
          Button("Back to scanner") { resumeScanning() }
            .font(.fuelBody(.subheadline, weight: 600))
            .foregroundStyle(Color.fuelCitrusInk)
        }
      }
    }
    .task { codeFieldFocused = true }
  }

  private func softStateScreen(icon: String, title: LocalizedStringKey, message: LocalizedStringKey, code: String) -> some View {
    contentScaffold {
      VStack(spacing: 16) {
        Image(systemName: icon)
          .font(.system(size: 40))
          .foregroundStyle(Color.fuelCitrusInk)
        Text(title)
          .font(.fuelTitle2)
          .foregroundStyle(Color.fuelInk)
        Text(message)
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
          .multilineTextAlignment(.center)

        Button {
          reviewContext = LabelReviewContext(review: LabelPortion.manualReview())
        } label: {
          Text("Enter details manually").frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .tint(.fuelCitrus)

        if cameraReady {
          Button("Scan another") { resumeScanning() }
            .font(.fuelBody(.subheadline, weight: 600))
            .foregroundStyle(Color.fuelCitrusInk)
        } else {
          Button("Enter a different code") { openManualEntry() }
            .font(.fuelBody(.subheadline, weight: 600))
            .foregroundStyle(Color.fuelCitrusInk)
        }
      }
    }
  }

  private func failureScreen(error: PresentableError, code: String?) -> some View {
    contentScaffold {
      VStack(spacing: 16) {
        ErrorBanner(
          error: error,
          onRetry: code.map { c in { look(up: c) } },
          onDismiss: nil
        )
        Button {
          reviewContext = LabelReviewContext(review: LabelPortion.manualReview())
        } label: {
          Text("Enter details manually").frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        .tint(.fuelCitrus)
        if cameraReady {
          Button("Back to scanner") { resumeScanning() }
            .font(.fuelBody(.subheadline, weight: 600))
            .foregroundStyle(Color.fuelCitrusInk)
        }
      }
    }
  }

  private var loggedScreen: some View {
    contentScaffold {
      VStack(spacing: 16) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 48))
          .foregroundStyle(Color.fuelVoltInk)
        Text("Logged")
          .font(.fuelTitle2)
          .foregroundStyle(Color.fuelInk)
        Text("Added to today. Scan another product or you're done.")
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
          .multilineTextAlignment(.center)

        if cameraReady {
          Button {
            resumeScanning()
          } label: {
            Label("Scan again", systemImage: "barcode.viewfinder")
              .frame(maxWidth: .infinity).padding(.vertical, 4)
          }
          .buttonStyle(.glassProminent)
          .tint(.fuelCitrus)
        } else {
          Button {
            manualCode = ""
            openManualEntry()
          } label: {
            Label("Scan another", systemImage: "barcode.viewfinder")
              .frame(maxWidth: .infinity).padding(.vertical, 4)
          }
          .buttonStyle(.glassProminent)
          .tint(.fuelCitrus)
        }

        Button("Done") { dismiss() }
          .font(.fuelBody(.subheadline, weight: 600))
          .foregroundStyle(Color.fuelCitrusInk)
      }
    }
  }

  // A centered card on the app background, with a Cancel toolbar-style header.
  private func contentScaffold<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    ZStack(alignment: .top) {
      Color.fuelBackground.ignoresSafeArea()
      VStack {
        HStack {
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.body.weight(.semibold))
              .frame(width: 30, height: 30)
          }
          .buttonStyle(.glass)
          .tint(.fuelInk)
          .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        Spacer()
      }
      content()
        .padding(28)
        .frame(maxWidth: 460)
    }
  }

  // MARK: - Setup & flow

  private func setUp() async {
    guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
      stage = .manualEntry(reason: .unsupported)
      return
    }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      cameraReady = true
      resumeScanning()
    case .notDetermined:
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      if granted {
        cameraReady = true
        resumeScanning()
      } else {
        stage = .manualEntry(reason: .denied)
      }
    default:
      stage = .manualEntry(reason: .denied)
    }
  }

  private func resumeScanning() {
    manualCode = ""
    torchOn = false
    stage = .scanning
    isScanning = true
  }

  private func openManualEntry() {
    isScanning = false
    torchOn = false
    stage = .manualEntry(reason: nil)
  }

  private func handleScan(_ raw: String) {
    let code = BarcodeCode.normalized(raw)
    guard BarcodeCode.isValid(code) else { return } // ignore stray non-retail reads
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    look(up: code)
  }

  private func look(up code: String) {
    guard BarcodeCode.isValid(code) else { return }
    codeFieldFocused = false
    isScanning = false
    torchOn = false
    stage = .lookingUp(code: code)
    Task {
      do {
        let product = try await FuelAPI.barcodeLookup(code: code)
        if product.found {
          reviewContext = LabelReviewContext(review: LabelPortion.toReview(product), brand: product.brand)
        } else {
          stage = .notFound(code: code)
        }
      } catch {
        stage = .failed(PresentableError(error), code: code)
      }
    }
  }

  private func handleReviewDismiss() {
    if didLogFromReview {
      didLogFromReview = false
      stage = .logged
    } else if cameraReady {
      resumeScanning()
    } else {
      openManualEntry()
    }
  }
}

#Preview {
  BarcodeScanView()
    .environment(AppState())
}
