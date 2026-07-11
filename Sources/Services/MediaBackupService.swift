import Foundation
import Photos
import SwiftUI

@MainActor
public class MediaBackupService: ObservableObject {
    @Published var isBackingUp = false
    @Published var totalToBackup = 0
    @Published var currentBackupIndex = 0
    @Published var currentFilename = ""
    @Published var permissionStatus: PHAuthorizationStatus = .notDetermined
    
    private let uploadedAssetsKey = "com.smbbackup.uploadedAssetIDs"
    
    public init() {
        self.permissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    /// Requests access to the Photo Library
    public func requestPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.permissionStatus = status
        return status == .authorized || status == .limited
    }
    
    /// Returns the set of IDs of already backed-up photos/videos
    private func getUploadedAssetIDs() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: uploadedAssetsKey) ?? []
        return Set(array)
    }
    
    /// Saves the set of backed-up photo/video IDs
    private func saveUploadedAssetIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: uploadedAssetsKey)
    }
    
    /// Resets the backup history (allows re-uploading everything)
    public func resetBackupHistory() {
        UserDefaults.standard.removeObject(forKey: uploadedAssetsKey)
    }
    
    /// Starts the backup process (can be run manually or from a background task)
    /// - Parameters:
    ///   - smbService: The connected SMBService instance
    ///   - config: The connection config
    ///   - expirationHandler: A closure called if the background task is expiring
    /// - Returns: A tuple indicating success, count of uploaded files, total bytes uploaded, and error message
    public func performBackup(
        smbService: SMBService,
        config: SMBConnectionConfig,
        expirationHandler: (() -> Bool)? = nil
    ) async -> (success: Bool, count: Int, bytes: Int64, error: String?) {
        
        self.isBackingUp = true
        self.totalToBackup = 0
        self.currentBackupIndex = 0
        self.currentFilename = ""
        
        defer {
            self.isBackingUp = false
        }
        
        // 1. Ensure permission is granted
        if permissionStatus != .authorized && permissionStatus != .limited {
            let granted = await requestPermission()
            if !granted {
                return (false, 0, 0, "Zugriff auf Fotos verweigert")
            }
        }
        
        // 2. Connect to SMB server if not already connected
        if !smbService.isConnected {
            let connected = await smbService.connect(config: config)
            if !connected {
                return (false, 0, 0, "Konnte keine Verbindung zum SMB-Server herstellen: \(smbService.connectionError ?? "")")
            }
        }
        
        // 3. Ensure target directory exists on SMB server
        let targetPath = config.path
        if targetPath != "/" && !targetPath.isEmpty {
            let exists = await smbService.fileExists(atPath: targetPath)
            if !exists {
                do {
                    try await smbService.createDirectory(atPath: targetPath)
                } catch {
                    return (false, 0, 0, "Konnte Zielordner nicht erstellen: \(error.localizedDescription)")
                }
            }
        }
        
        // 4. Fetch all photos & videos from photo library
        let fetchOptions = PHFetchOptions()
        // Sort oldest first so that backup goes in chronological order
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let allAssets = PHAsset.fetchAssets(with: fetchOptions)
        var uploadedIDs = getUploadedAssetIDs()
        
        // Find assets that haven't been backed up yet
        var assetsToBackup: [PHAsset] = []
        allAssets.enumerateObjects { asset, _, _ in
            if !uploadedIDs.contains(asset.localIdentifier) {
                assetsToBackup.append(asset)
            }
        }
        
        self.totalToBackup = assetsToBackup.count
        
        if assetsToBackup.isEmpty {
            return (true, 0, 0, nil)
        }
        
        var successCount = 0
        var totalBytes: Int64 = 0
        var lastErrorMsg: String? = nil
        let tempDir = FileManager.default.temporaryDirectory
        
        // 5. Iterate and upload each asset
        for (index, asset) in assetsToBackup.enumerated() {
            // Check for background task expiration
            if let isExpired = expirationHandler?, isExpired() {
                lastErrorMsg = "Hintergrundaufgabe durch iOS vorzeitig beendet"
                break
            }
            
            self.currentBackupIndex = index + 1
            
            // Get resources associated with the asset (original file)
            let resources = PHAssetResource.assetResources(for: asset)
            guard let resource = resources.first(where: { $0.type == .photo || $0.type == .video }) ?? resources.first else {
                continue
            }
            
            let originalFilename = resource.originalFilename
            self.currentFilename = originalFilename
            
            // Generate unique temporary URL for exporting
            let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension((originalFilename as NSString).pathExtension)
            
            do {
                // Export original asset resource to temp local file
                try await exportResource(resource, to: tempFileURL)
                
                // Determine remote path
                let remoteFilePath = targetPath == "/" ? "/\(originalFilename)" : "\(targetPath)/\(originalFilename)"
                
                // Check if file already exists on server
                let fileExistsOnServer = await smbService.fileExists(atPath: remoteFilePath)
                
                if fileExistsOnServer {
                    // Item already exists on server, skip upload but mark it as backed up
                    uploadedIDs.insert(asset.localIdentifier)
                    successCount += 1
                } else {
                    // Upload to SMB
                    try await smbService.uploadFile(localURL: tempFileURL, remotePath: remoteFilePath)
                    
                    // Add to uploaded list
                    uploadedIDs.insert(asset.localIdentifier)
                    successCount += 1
                    
                    // Track size
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: tempFileURL.path),
                       let fileSize = attrs[.size] as? Int64 {
                        totalBytes += fileSize
                    }
                }
                
                // Save progress incrementally
                saveUploadedAssetIDs(uploadedIDs)
                
            } catch {
                lastErrorMsg = error.localizedDescription
                print("Fehler beim Backup von \(originalFilename): \(error.localizedDescription)")
            }
            
            // Clean up temporary local file
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        // Log this run
        let logStatus: BackupLog.LogStatus = (lastErrorMsg == nil) ? .success : .failure
        let log = BackupLog(
            filesUploadedCount: successCount,
            totalBytesUploaded: totalBytes,
            status: logStatus,
            errorMessage: lastErrorMsg,
            uploadedFiles: assetsToBackup.prefix(successCount).map { asset in
                let res = PHAssetResource.assetResources(for: asset)
                return res.first?.originalFilename ?? "Unbenannt"
            }
        )
        BackupLog.addLog(log)
        
        return (lastErrorMsg == nil, successCount, totalBytes, lastErrorMsg)
    }
    
    /// Helper to export PHAssetResource to a local URL asynchronously
    private func exportResource(_ resource: PHAssetResource, to fileURL: URL) async throws {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true // Allow downloading from iCloud
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: fileURL, options: options) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
