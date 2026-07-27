import SwiftUI
import UIKit

// Thin UIViewControllerRepresentable over UIImagePickerController's camera. Used
// only when `UIImagePickerController.isSourceTypeAvailable(.camera)` (never in
// the simulator, where the photo flow offers the library instead). The library
// side uses SwiftUI's native PhotosPicker, so this wraps just the camera.
struct CameraPicker: UIViewControllerRepresentable {
  var onImage: (UIImage) -> Void
  @Environment(\.dismiss) private var dismiss

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let parent: CameraPicker
    init(_ parent: CameraPicker) { self.parent = parent }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      if let image = info[.originalImage] as? UIImage {
        parent.onImage(image)
      }
      parent.dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      parent.dismiss()
    }
  }
}
