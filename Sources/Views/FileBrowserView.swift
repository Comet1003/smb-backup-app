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
                Color(red: 0.04, green: 0.04, blue: 0.08)
                    .ignoresSafeArea()
                
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 350, height: 350)
                    .blur(radius: 90)
                    .offset(x: -120, y: -250)
                
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: 140, y: 220)
                
                VStack(spacing: 0) {
                    // Connection Status bar
                    if !smbService.isConnected {
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text("Nicht verbunden")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Bitte verbinde dich zuerst im Tab 'Setup' mit deinem SMB-Server.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // Current Path breadcrumb (Glass style)
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.cyan)
                            Text(currentPath)
                                .font(.caption)
                                .monospaced()
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color.white.opacity(0.1)),
                            alignment: .bottom
                        )
                        
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
                                        .foregroundColor(.cyan)
                                        .bold()
                                }
                                ProgressView(value: smbService.transferProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                            }
                            .padding()
                            .background(Color.cyan.opacity(0.12))
                        }
                        
                        // File List (ScrollView with custom Glass Rows for a highly premium aesthetic)
                        ScrollView {
                            VStack(spacing: 12) {
                                // Up folder button
                                if currentPath != "/" {
                                    Button(action: {
                                        goUpOneDirectory()
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.turn.up.left")
                                                .foregroundColor(.cyan)
                                                .bold()
                                            Text("Übergeordneter Ordner")
                                                .foregroundColor(.cyan)
                                                .bold()
                                            Spacer()
                                        }
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                    }
                                }
                                
                                if smbService.fileItems.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "folder.badge.questionmark")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                        Text("Dieser Ordner ist leer.")
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding(.top, 50)
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
                                                        .foregroundColor(.white.opacity(0.4))
                                                        .font(.caption)
                                                }
                                                .padding()
                                                .background(.ultraThinMaterial)
                                                .cornerRadius(18)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                            }
                                        } else {
                                            HStack {
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
                                                                    .foregroundColor(.white.opacity(0.5))
                                                                
                                                                if let date = item.modificationDate {
                                                                    Text(formatDate(date))
                                                                        .font(.caption2)
                                                                        .foregroundColor(.white.opacity(0.5))
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
                                                        .foregroundColor(.cyan)
                                                }
                                                .buttonStyle(BorderlessButtonStyle())
                                            }
                                            .padding()
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(18)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
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
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
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
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        )
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
                                            .cornerRadius(14)
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
                                        .cornerRadius(14)
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
                                    .background(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                        )
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
                                .foregroundColor(.cyan)
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
            return .cyan
        case "mp4", "mov", "m4v", "avi":
            return .purple
        default:
            return .white.opacity(0.7)
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
