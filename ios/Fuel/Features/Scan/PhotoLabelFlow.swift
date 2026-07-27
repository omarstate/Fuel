import SwiftUI
import PhotosUI
import UIKit

// Photo nutrition-label flow. The user takes a photo (camera) or picks one from
// their library; we downscale + JPEG-compress it (ImageCompression), upload the
// raw base64 to Gemini vision, and route the result into the shared review
// sheet. The upload is slow (10–40s) so it shows the chosen photo plus rotating
// AIProgressView hints. An unreadable photo is a soft state — retake or enter by
// hand — never an error. Simulator has no camera, so only the library option
// shows there.
struct PhotoLabelFlow: View {
  @Environment(\.dismiss) private var dismiss

  @State private var stage: Stage = .choosing
  @State private var libraryItem: PhotosPickerItem?
  @State private var showCamera = false
  @State private var reviewContext: LabelReviewContext?
  @State private var didLogFromReview = false

  private enum Stage {
    case choosing
    case extracting(preview: UIImage)
    case unreadable(note: String, preview: UIImage?)
    case failed(PresentableError)
  }

  private var cameraAvailable: Bool {
    UIImagePickerController.isSourceTypeAvailable(.camera)
  }

  private let hints: [LocalizedStringKey] = [
    "Reading the label…",
    "Finding the nutrition panel…",
    "Crunching the numbers…",
    "Converting units…",
  ]

  var body: some View {
    NavigationStack {
      Group {
        switch stage {
        case .choosing:
          chooseScreen
        case let .extracting(preview):
          extractingScreen(preview: preview)
        case let .unreadable(note, preview):
          unreadableScreen(note: note, preview: preview)
        case let .failed(error):
          failedScreen(error: error)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.fuelBackground)
      .navigationTitle("Photo label")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Cancel") { dismiss() }
            .disabled(isExtracting)
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .interactiveDismissDisabled(isExtracting)
    .fullScreenCover(isPresented: $showCamera) {
      CameraPicker { image in ingest(image) }
        .ignoresSafeArea()
    }
    .onChange(of: libraryItem) { _, item in
      guard let item else { return }
      Task { await loadLibrary(item) }
    }
    .sheet(item: $reviewContext, onDismiss: handleReviewDismiss) { ctx in
      LabelReviewSheet(review: ctx.review, brand: ctx.brand) {
        didLogFromReview = true
      }
    }
  }

  private var isExtracting: Bool {
    if case .extracting = stage { return true }
    return false
  }

  // MARK: - Choose source

  private var chooseScreen: some View {
    VStack(spacing: 20) {
      Image(systemName: "text.viewfinder")
        .font(.system(size: 46))
        .foregroundStyle(Color.fuelVoltInk)
      VStack(spacing: 6) {
        Text("Snap a nutrition label")
          .font(.fuelTitle2)
          .foregroundStyle(Color.fuelInk)
        Text("Point at the Nutrition Facts panel — English or Arabic, per-100g or per-serving. We read the macros; you confirm the portion.")
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 8)

      VStack(spacing: 12) {
        if cameraAvailable {
          Button {
            showCamera = true
          } label: {
            Label("Take a photo", systemImage: "camera.fill")
              .frame(maxWidth: .infinity).padding(.vertical, 6)
          }
          .buttonStyle(.glassProminent)
          .tint(.fuelCitrus)
        }

        Group {
          if cameraAvailable {
            PhotosPicker(selection: $libraryItem, matching: .images, photoLibrary: .shared()) {
              Label("Choose from library", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glass)
          } else {
            PhotosPicker(selection: $libraryItem, matching: .images, photoLibrary: .shared()) {
              Label("Choose from library", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
          }
        }
        .tint(.fuelCitrus)
      }
      .padding(.top, 4)
    }
    .padding(28)
    .frame(maxWidth: 460)
  }

  // MARK: - Extracting

  private func extractingScreen(preview: UIImage) -> some View {
    VStack(spacing: 24) {
      Image(uiImage: preview)
        .resizable()
        .scaledToFill()
        .frame(width: 180, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.fuelSubtle.opacity(0.2), lineWidth: 1)
        )
      AIProgressView(hints: hints, title: "Reading your label…")
    }
    .padding(28)
  }

  // MARK: - Soft-fail & error states

  private func unreadableScreen(note: String, preview: UIImage?) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "eye.trianglebadge.exclamationmark")
        .font(.system(size: 42))
        .foregroundStyle(Color.fuelCitrusInk)
      Text("Couldn't read the label")
        .font(.fuelTitle2)
        .foregroundStyle(Color.fuelInk)
      Text(note.isEmpty
        ? String(localized: "Get the whole Nutrition Facts panel in frame, well lit and in focus, then try again.")
        : note)
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
        .multilineTextAlignment(.center)

      VStack(spacing: 12) {
        retakeButton(prominent: true)
        Button {
          reviewContext = LabelReviewContext(review: LabelPortion.manualReview())
        } label: {
          Text("Enter values manually").frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        .tint(.fuelCitrus)
      }
      .padding(.top, 4)
    }
    .padding(28)
    .frame(maxWidth: 460)
  }

  private func failedScreen(error: PresentableError) -> some View {
    VStack(spacing: 16) {
      ErrorBanner(error: error, onDismiss: nil)
      retakeButton(prominent: true)
      Button {
        reviewContext = LabelReviewContext(review: LabelPortion.manualReview())
      } label: {
        Text("Enter values manually").frame(maxWidth: .infinity).padding(.vertical, 4)
      }
      .buttonStyle(.glass)
      .tint(.fuelCitrus)
    }
    .padding(28)
    .frame(maxWidth: 460)
  }

  @ViewBuilder
  private func retakeButton(prominent: Bool) -> some View {
    if cameraAvailable {
      Button {
        showCamera = true
      } label: {
        Label("Retake photo", systemImage: "camera.fill")
          .frame(maxWidth: .infinity).padding(.vertical, 4)
      }
      .buttonStyle(.glassProminent)
      .tint(.fuelCitrus)
    } else {
      PhotosPicker(selection: $libraryItem, matching: .images, photoLibrary: .shared()) {
        Label("Choose another photo", systemImage: "photo.on.rectangle")
          .frame(maxWidth: .infinity).padding(.vertical, 4)
      }
      .buttonStyle(.glassProminent)
      .tint(.fuelCitrus)
    }
  }

  // MARK: - Pipeline

  private func loadLibrary(_ item: PhotosPickerItem) async {
    libraryItem = nil
    do {
      guard let data = try await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data) else {
        stage = .failed(PresentableError(message: String(localized: "Couldn't open that photo. Try another.")))
        return
      }
      ingest(image)
    } catch {
      stage = .failed(PresentableError(message: String(localized: "Couldn't open that photo. Try another.")))
    }
  }

  private func ingest(_ image: UIImage) {
    let compressed: ImageCompression.Result
    do {
      compressed = try ImageCompression.compress(image)
    } catch {
      stage = .failed(PresentableError(error))
      return
    }
    stage = .extracting(preview: compressed.preview)
    Task {
      do {
        let label = try await FuelAPI.extractLabel(imageBase64: compressed.base64, mimeType: compressed.mimeType)
        if label.ok, label.readable {
          reviewContext = LabelReviewContext(review: LabelPortion.toReview(label))
        } else {
          stage = .unreadable(note: label.note, preview: compressed.preview)
        }
      } catch {
        stage = .failed(PresentableError(error))
      }
    }
  }

  private func handleReviewDismiss() {
    if didLogFromReview {
      dismiss()
    } else {
      stage = .choosing
    }
  }
}

#Preview {
  PhotoLabelFlow()
    .environment(AppState())
}
