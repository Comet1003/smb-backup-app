import SwiftUI
import Photos
import AVKit

public struct FileBrowserView: View {
    @ObservedObject var smbService: SMBService
    
    @State private var currentPath = "/"
    @State private var showPhotoPicker = false
    
    // Notification & Alert states
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isDownloading = false
    
    // Preview States
    @State private var selectedPreviewItem: SMBFileItem?
    @State private var previewLocalURL: URL?
    @State private var isDownloadingPreview = false
    
    public init(smbService: SMBService) {
        self.smbService = smbService
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.1, green: 0.12, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Connection Status bar
                    if !smbService.isConnected {
                        VStack(spacing: 12) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            Text("Nicht verbunden")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Bitte verbinde dich zuerst im Tab 'Setup' mit deinem SMB-Server.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // Current Path breadcrumb
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(currentPath)
                                .font(.caption)
                                .monospaced()
                                .foregroundColor(Color.white.opacity(0.8))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                        
                        // Active File Transfer Progress Overlay
                        if smbService.isTransferring {
                            VStack(spacing: 8) {
                                HStack {
                                    Text(smbService.currentTransferFile)
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(Int(smbService.transferProgress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .bold()
                                }
                                ProgressView(value: smbService.transferProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                        }
                        
                        // File List
                        List {
                            // Up folder button
                            if currentPath != "/" {
                                Button(action: {
                                    goUpOneDirectory()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.turn.up.left")
                                            .foregroundColor(.blue)
                                        Text("Übergeordneter Ordner")
                                            .foregroundColor(.blue)
                                            .bold()
                                    }
                                }
                                .listRowBackground(Color.white.opacity(0.02))
                            }
                            
                            if smbService.fileItems.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("Dieser Ordner ist leer.")
                                        .foregroundColor(.gray)
                                        .padding()
                                    Spacer()
                                }
                                .listRowBackground(Color.clear)
                            } else {
                                ForEach(smbService.fileItems) { item in
                                    if item.isDirectory {
                                        Button(action: {
                                            navigateIntoDirectory(name: item.name)
                                        }) {
                                            HStack {
                                                Image(systemName: "folder.fill")
                                                    .foregroundColor(.yellow)
                                                    .frame(width: 30)
                                                VStack(alignment: .leading) {
                                                    Text(item.name)
                                                        .foregroundColor(.white)
                                                        .bold()
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray)
                                                    .font(.caption)
                                            }
                                        }
                                    } else {
                                        HStack {
                                            // Make the file row tappable for preview
                                            Button(action: {
                                                openPreview(for: item)
                                            }) {
                                                HStack {
                                                    Image(systemName: getFileIcon(filename: item.name))
                                                        .foregroundColor(getFileIconColor(filename: item.name))
                                                        .frame(width: 30)
                                                    
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(item.name)
                                                            .foregroundColor(.white)
                                                            .lineLimit(1)
                                                            .multilineTextAlignment(.leading)
                                                        
                                                        HStack(spacing: 12) {
                                                            Text(formatBytes(item.size))
                                                                .font(.caption2)
                                                                .foregroundColor(.gray)
                                                            
                                                            if let date = item.modificationDate {
                                                                Text(formatDate(date))
                                                                    .font(.caption2)
                                                                    .foregroundColor(.gray)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                downloadFileToPhotos(item: item)
                                            }) {
                                                Image(systemName: "arrow.down.circle")
                                                    .font(.title3)
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                    }
                                }
                                .listRowBackground(Color.white.opacity(0.03))
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            await refreshDirectory()
                        }
                    }
                }
                
                // Loading Overlay for Preview
                if isDownloadingPreview {
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Vorschau wird geladen...")
                                .foregroundColor(.white)
                                .bold()
                            if smbService.isTransferring {
                                Text("\(Int(smbService.transferProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(30)
                        .background(Color(red: 0.1, green: 0.12, blue: 0.2))
                        .cornerRadius(15)
                        .shadow(radius: 10)
                    }
                }
                
                // Preview Overlay Modal
                if let previewItem = selectedPreviewItem, let localURL = previewLocalURL, !isDownloadingPreview {
                    ZStack {
                        Color.black.opacity(0.8)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closePreview()
                            }
                        
                        VStack(spacing: 20) {
                            HStack {
                                Text(previewItem.name)
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: {
                                    closePreview()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                            // Preview content container
                            Group {
                                if isImageFile(filename: previewItem.name) {
                                    if let uiImage = UIImage(contentsOfFile: localURL.path) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(10)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else {
                                        VStack {
                                            Image(systemName: "photo")
                                                .font(.system(size: 60))
                                                .foregroundColor(.gray)
                                            Text("Bild konnte nicht geladen werden")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                } else if isVideoFile(filename: previewItem.name) {
                                    VideoPlayer(player: AVPlayer(url: localURL))
                                        .cornerRadius(10)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    VStack(spacing: 12) {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.gray)
                                        Text("Keine Vorschau verfügbar")
                                            .foregroundColor(.gray)
                                        Text(formatBytes(previewItem.size))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .frame(maxHeight: 350)
                            .padding(.horizontal)
                            
                            // Share link
                            ShareLink(item: localURL, preview: SharePreview(previewItem.name, image: Image(systemName: "doc"))) {
                                Label("Teilen / Sichern", systemImage: "square.and.arrow.up")
                                    .bold()
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        }
                        .background(Color(red: 0.08, green: 0.09, blue: 0.15))
                        .cornerRadius(20)
                        .shadow(radius: 20)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("Dateien")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if smbService.isConnected {
                        Button(action: {
                            showPhotoPicker = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(onCompletion: { urls in
                    uploadSelectedPhotos(urls: urls)
                })
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                if smbService.isConnected {
                    Task {
                        await smbService.listDirectory(atPath: currentPath)
                    }
                }
            }
        }
    }
    
    // Helpers
    private func refreshDirectory() async {
        _ = await smbService.listDirectory(atPath: currentPath)
    }
    
    private func navigateIntoDirectory(name: String) {
        let newPath = currentPath == "/" ? "/\(name)" : "\(currentPath)/\(name)"
        currentPath = newPath
        Task {
            await smbService.listDirectory(atPath: currentPath)
        }
    }
    
    private func goUpOneDirectory() {
        let components = currentPath.components(separatedBy: "/")
        if components.count <= 2 {
            currentPath = "/"
        } else {
            currentPath = components.dropLast().joined(separator: "/")
        }
        Task {
            await smbService.listDirectory(atPath: currentPath)
        }
    }
    
    private func getFileIcon(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic", "raw":
            return "photo.fill"
        case "mp4", "mov", "m4v", "avi":
            return "video.fill"
        default:
            return "doc.fill"
        }
    }
    
    private func getFileIconColor(filename: String) -> Color {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic", "raw":
            return .blue
        case "mp4", "mov", "m4v", "avi":
            return .purple
        default:
            return .gray
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func isImageFile(filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "raw"].contains(ext)
    }
    
    private func isVideoFile(filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["mp4", "mov", "m4v", "avi"].contains(ext)
    }
    
    // Preview actions
    private func openPreview(for item: SMBFileItem) {
        selectedPreviewItem = item
        isDownloadingPreview = true
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("preview_" + UUID().uuidString + "_" + item.name)
        previewLocalURL = tempURL
        
        Task {
            do {
                try await smbService.downloadFile(remotePath: item.path, localURL: tempURL)
                isDownloadingPreview = false
            } catch {
                isDownloadingPreview = false
                alertTitle = "Fehler"
                alertMessage = "Vorschau konnte nicht geladen werden: \(error.localizedDescription)"
                showAlert = true
                closePreview()
            }
        }
    }
    
    private func closePreview() {
        if let url = previewLocalURL {
            try? FileManager.default.removeItem(at: url)
        }
        selectedPreviewItem = nil
        previewLocalURL = nil
        isDownloadingPreview = false
    }
    
    // Download logic
    private func downloadFileToPhotos(item: SMBFileItem) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(UUID().uuidString + "_" + item.name)
        
        isDownloading = true
        
        Task {
            do {
                try await smbService.downloadFile(remotePath: item.path, localURL: tempURL)
                
                // Save to photo library
                try await saveFileToCameraRoll(fileURL: tempURL)
                
                alertTitle = "Erfolgreich"
                alertMessage = "\(item.name) wurde auf dein iPhone heruntergeladen und in Fotos gesichert."
                showAlert = true
            } catch {
                alertTitle = "Fehler"
                alertMessage = "Download fehlgeschlagen: \(error.localizedDescription)"
                showAlert = true
            }
            
            // Clean up temporary local file
            try? FileManager.default.removeItem(at: tempURL)
            isDownloading = false
        }
    }
    
    // PhotoKit Camera Roll save helper
    private func saveFileToCameraRoll(fileURL: URL) async throws {
        // Request Photo Library Permission first
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "FileBrowserView", code: 403, userInfo: [NSLocalizedDescriptionKey: "Zugriff auf Fotomediathek nicht erlaubt."])
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            let ext = fileURL.pathExtension.lowercased()
            if ["mp4", "mov", "m4v"].contains(ext) {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            } else {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
            }
        }
    }
    
    // Manual upload logic
    private func uploadSelectedPhotos(urls: [URL]) {
        if urls.isEmpty { return }
        
        Task {
            for url in urls {
                let remotePath = currentPath == "/" ? "/\(url.lastPathComponent)" : "\(currentPath)/\(url.lastPathComponent)"
                do {
                    try await smbService.uploadFile(localURL: url, remotePath: remotePath)
                } catch {
                    alertTitle = "Fehler beim Upload"
                    alertMessage = "\(url.lastPathComponent) konnte nicht hochgeladen werden: \(error.localizedDescription)"
                    showAlert = true
                    break
                }
                // Delete local temp file
                try? FileManager.default.removeItem(at: url)
            }
            
            // Refresh listing
            await refreshDirectory()
        }
    }
}
