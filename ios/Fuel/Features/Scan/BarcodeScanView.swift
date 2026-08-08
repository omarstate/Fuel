import SwiftUI
import VisionKit
import AVFoundation

// Full-screen barcode flow. It opens on a chooser naming the two things a scan
// can do — ADD TO LIBRARY (scan → prefilled catalog form → saved to the shared
// meal database, the original flow) and QUICK LOG (scan → portion review with
// a section picker → straight into today's log, reusing the photo flow's
// LabelReviewSheet). Only after a pick does the camera spin up, so the capture
// session always starts from a user gesture. On a capable device with camera
// permission it shows the live VisionKit scanner under a Liquid-Glass overlay
// (reticle, torch, cancel, "type the code"); on the first hit it stops, looks
// the code up via Open Food Facts, and routes by the chosen purpose. Simulator
// / unsupported / permission-denied fall back cleanly to manual code entry.
// Soft states (not found, no macros) and outages each get a designed screen
// with a purpose-matched escape hatch — hand-enter into the catalog form, or
// hand-enter and log — and a "scan again" affordance closes the loop.
struct BarcodeScanView: View {
  /// Section to preselect when a quick-log scan reaches the review sheet
  /// (e.g. the Add-meal panel, which is already scoped to one section).
  var preselectedType: MealType? = nil
  /// Called with the created catalog meal after a successful save, so hosts
  /// showing the catalog (the add panel) can invalidate their cached pages.
  var onSaved: (CatalogMeal) -> Void = { _ in }

  @Environment(\.dismiss) private var dismiss

  @State private var stage: Stage = .choosing
  @State private var purpose: Purpose = .quickLog
  @State private var cameraReady = false
  @State private var isScanning = false
  @State private var torchOn = false
  @State private var manualCode = ""
  @State private var formContext: CatalogFormContext?
  @State private var didSaveFromForm = false
  @State private var reviewContext: LabelReviewContext?
  @State private var didLogFromReview = false
  @FocusState private var codeFieldFocused: Bool

  /// What the scan is FOR — picked on the opening screen. Drives where a found
  /// product goes (the shared catalog vs today's log) and every escape hatch.
  private enum Purpose {
    case addToCatalog
    case quickLog
  }

  private enum Stage: Equatable {
    case choosing
    case initializing
    case scanning
    case lookingUp(code: String)
    case manualEntry(reason: FallbackReason?)
    case notFound(code: String)
    case failed(PresentableError, code: String?)
    case saved
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
    .sheet(item: $formContext, onDismiss: handleFormDismiss) { ctx in
      CatalogMealForm(mode: .create, prefill: ctx.prefill) { meal in
        didSaveFromForm = true
        onSaved(meal)
      }
    }
    .sheet(item: $reviewContext, onDismiss: handleReviewDismiss) { ctx in
      LabelReviewSheet(review: ctx.review, brand: ctx.brand, preselectedType: preselectedType) {
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
    case .choosing:
      chooserScreen
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
        message: purpose == .quickLog
          ? "\(code) isn't in the barcode database yet. Enter its details by hand to log it anyway."
          : "\(code) isn't in the barcode database yet. Enter its details by hand to add it to the meal library.",
        code: code
      )
    case let .failed(error, code):
      failureScreen(error: error, code: code)
    case .saved:
      successScreen(
        title: "Added to library",
        message: "Saved to the meal database — log it from the catalog whenever you eat it. Scan another product or you're done."
      )
    case .logged:
      successScreen(
        title: "Logged to today",
        message: "It's on today's log. Scan another product or you're done."
      )
    }
  }

  // MARK: - Purpose chooser

  // The two things a scan can do, as two big cards. The camera only starts
  // after a pick, so the capture session always begins from a user gesture.
  private var chooserScreen: some View {
    contentScaffold {
      VStack(spacing: 24) {
        VStack(spacing: 10) {
          Image(systemName: "barcode.viewfinder")
            .font(.system(size: 40))
            .foregroundStyle(Color.fuelVoltInk)
          Text("Scan a barcode")
            .font(.fuelTitle2)
            .foregroundStyle(Color.fuelInk)
          Text("What should this scan do?")
            .font(.fuelBody(.subheadline))
            .foregroundStyle(Color.fuelSubtle)
        }

        VStack(spacing: 12) {
          purposeCard(
            icon: "books.vertical.fill",
            tint: .fuelBlueInk,
            title: "Add to library",
            subtitle: "Save the product to the shared meal database — into your meals and everyone's catalog."
          ) { choose(.addToCatalog) }

          purposeCard(
            icon: "flame.fill",
            tint: .fuelVoltInk,
            title: "Quick log",
            subtitle: "Scan and log it straight into today — you pick which meal it lands in."
          ) { choose(.quickLog) }
        }
      }
    }
  }

  private func purposeCard(
    icon: String,
    tint: Color,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: icon)
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: 52, height: 52)
          .background(tint.opacity(0.14), in: .rect(cornerRadius: 16))
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.fuelHeading(.headline))
            .foregroundStyle(Color.fuelInk)
          Text(subtitle)
            .font(.fuelBody(.footnote))
            .foregroundStyle(Color.fuelSubtle)
            .multilineTextAlignment(.leading)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Color.fuelSubtle)
      }
      .padding(16)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .fuelCard()
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
        Text(purpose == .quickLog ? "Scan to log to today" : "Scan to add to the library")
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
          openManualDetails()
        } label: {
          Text(manualDetailsTitle).frame(maxWidth: .infinity).padding(.vertical, 4)
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
          openManualDetails()
        } label: {
          Text(manualDetailsTitle).frame(maxWidth: .infinity).padding(.vertical, 4)
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

  // Shared terminal screen for both purposes ("Added to library" / "Logged to
  // today"): a check, the purpose's message, scan-again, done.
  private func successScreen(title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
    contentScaffold {
      VStack(spacing: 16) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 48))
          .foregroundStyle(Color.fuelVoltInk)
        Text(title)
          .font(.fuelTitle2)
          .foregroundStyle(Color.fuelInk)
        Text(message)
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

  private func choose(_ p: Purpose) {
    purpose = p
    stage = .initializing
    Task { await setUp() }
  }

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
          route(found: product)
        } else {
          stage = .notFound(code: code)
        }
      } catch {
        stage = .failed(PresentableError(error), code: code)
      }
    }
  }

  /// A found product goes where the chosen purpose says: the catalog form to
  /// save it to the shared database, or the review sheet to log it to today.
  private func route(found product: BarcodeProduct) {
    switch purpose {
    case .addToCatalog:
      formContext = CatalogFormContext(prefill: Self.prefill(for: product))
    case .quickLog:
      reviewContext = LabelReviewContext(review: LabelPortion.toReview(product), brand: product.brand)
    }
  }

  /// The purpose-matched hand-entry escape hatch: a blank catalog form when
  /// adding to the library, a blank editable review (which logs to today and
  /// best-effort contributes to the catalog) for quick log.
  private func openManualDetails() {
    switch purpose {
    case .addToCatalog: formContext = CatalogFormContext(prefill: nil)
    case .quickLog: reviewContext = LabelReviewContext(review: LabelPortion.manualReview())
    }
  }

  private var manualDetailsTitle: LocalizedStringKey {
    purpose == .quickLog ? "Enter details & log" : "Enter details manually"
  }

  /// Map a found product onto the catalog form. Per-100g labels keep their
  /// basis explicit ("100 g" serving); per-serving labels carry the label's own
  /// serving string. Brand becomes the description so the name stays clean.
  private static func prefill(for product: BarcodeProduct) -> CatalogMealForm.Prefill {
    let serving: String
    switch product.basis {
    case .per100g: serving = "100 g"
    case .perServing:
      let s = product.servingSize.trimmingCharacters(in: .whitespaces)
      serving = s.isEmpty ? String(localized: "1 serving") : s
    }
    return CatalogMealForm.Prefill(
      name: product.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
      description: product.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
      servingSize: serving,
      calories: Int(product.calories.rounded()),
      protein: Int(product.protein.rounded()),
      carbs: Int(product.carbs.rounded()),
      fat: Int(product.fat.rounded())
    )
  }

  private func handleFormDismiss() {
    if didSaveFromForm {
      didSaveFromForm = false
      stage = .saved
    } else if cameraReady {
      resumeScanning()
    } else {
      openManualEntry()
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

// Identifiable wrapper so a scanned product's prefill (or a blank manual entry,
// `prefill == nil`) can drive `.sheet(item:)`.
private struct CatalogFormContext: Identifiable {
  let id = UUID()
  let prefill: CatalogMealForm.Prefill?
}

#Preview {
  BarcodeScanView()
    .environment(AppState())
}
