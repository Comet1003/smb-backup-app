import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

public struct PhotoPicker: UIViewControllerRepresentable {
    var onCompletion: ([URL]) -> Void

    public init(onCompletion: @escaping ([URL]) -> Void) {
        self.onCompletion = onCompletion
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        // Allow both images and videos
        config.filter = .any(of: [.images, .videos])
        // 0 means unlimited selection
        config.selectionLimit = 0
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            if results.isEmpty {
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var tempURLs: [URL] = []
            
            for result in results {
                dispatchGroup.enter()
                
                // Fetch the item provider
                let itemProvider = result.itemProvider
                
                // Determine representation type (image or video)
                let typeIdentifier = UTType.item.identifier
                
                itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { (url, error) in
                    if let url = url {
                        // Copy the temporary file to a secure directory (tmp) because url is deleted soon
                        let filename = url.lastPathComponent
                        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + filename)
                        
                        do {
                            if FileManager.default.fileExists(atPath: localURL.path) {
                                try FileManager.default.removeItem(at: localURL)
                            }
                            try FileManager.default.copyItem(at: url, to: localURL)
                            tempURLs.append(localURL)
                        } catch {
                            print("Fehler beim Kopieren des gewählten Mediums: \(error)")
                        }
                    } else if let error = error {
                        print("Fehler beim Laden der Datei-Repräsentation: \(error)")
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.parent.onCompletion(tempURLs)
            }
        }
    }
}
