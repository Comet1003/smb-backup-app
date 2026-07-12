import Foundation
import AMSMB2
import Combine

public struct SMBFileItem: Identifiable, Equatable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public let modificationDate: Date?
    
    public init(name: String, path: String, isDirectory: Bool, size: Int64, modificationDate: Date?) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate
    }
}

@MainActor
public class SMBService: ObservableObject {
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var connectionError: String? = nil
    @Published var fileItems: [SMBFileItem] = []
    
    // Transfer progress states
    @Published var isTransferring = false
    @Published var transferProgress: Double = 0.0
    @Published var currentTransferFile: String = ""
    
    private var manager: SMB2Manager?
    private var currentConfig: SMBConnectionConfig?
    
    public init() {}
    
    /// Connects to the SMB server using the stored config.
    public func connect(config: SMBConnectionConfig) async -> Bool {
        self.isConnecting = true
        self.connectionError = nil
        self.currentConfig = config
        
        guard let serverURL = config.serverURL else {
            self.connectionError = "Ungültige Server-URL"
            self.isConnecting = false
            return false
        }
        
        let password = KeychainHelper.shared.getPassword(forHost: config.host) ?? ""
        let credential = URLCredential(user: config.username, password: password, persistence: .forSession)
        
        // Initialize SMB2Manager
        guard let smbManager = SMB2Manager(url: serverURL, credential: credential) else {
            self.connectionError = "Konnte SMB-Manager nicht initialisieren"
            self.isConnecting = false
            return false
        }
        
        self.manager = smbManager
        
        do {
            try await smbManager.connectShare(name: config.share)
            self.isConnected = true
            self.isConnecting = false
            return true
        } catch {
            self.connectionError = "Verbindung fehlgeschlagen: \(error.localizedDescription)"
            self.isConnected = false
            self.isConnecting = false
            self.manager = nil
            return false
        }
    }
    
    /// Disconnects from the server
    public func disconnect() {
        self.manager = nil
        self.isConnected = false
        self.fileItems = []
        self.connectionError = nil
    }
    
    /// Tests connection and returns error message if any
    public func testConnection(config: SMBConnectionConfig, password: String) async -> (success: Bool, message: String) {
        guard let serverURL = config.serverURL else {
            return (false, "Ungültige Server-URL")
        }
        let credential = URLCredential(user: config.username, password: password, persistence: .forSession)
        guard let smbManager = SMB2Manager(url: serverURL, credential: credential) else {
            return (false, "Konnte SMB-Manager nicht initialisieren")
        }
        
        do {
            try await smbManager.connectShare(name: config.share)
            return (true, "Verbindung erfolgreich!")
        } catch {
            return (false, "Fehler: \(error.localizedDescription)")
        }
    }
    
    /// Lists contents of a path
    public func listDirectory(atPath path: String) async -> [SMBFileItem]? {
        guard let manager = manager else {
            self.connectionError = "Nicht verbunden"
            return nil
        }
        
        do {
            let entries = try await manager.contentsOfDirectory(atPath: path)
            var items: [SMBFileItem] = []
            
            for entry in entries {
                let name = entry[.nameKey] as? String ?? "Unbekannt"
                // Construct file path
                let rawPath = path == "/" ? "/\(name)" : "\(path)/\(name)"
                
                let size = entry[.fileSizeKey] as? Int64 ?? 0
                let type = entry[.fileResourceTypeKey] as? URLFileResourceType
                let isDir = type == .directory
                let modificationDate = entry[.contentModificationDateKey] as? Date
                
                items.append(SMBFileItem(
                    name: name,
                    path: rawPath,
                    isDirectory: isDir,
                    size: size,
                    modificationDate: modificationDate
                ))
            }
            
            // Sort directories first, then alphabetically
            items.sort {
                if $0.isDirectory != $1.isDirectory {
                    return $0.isDirectory && !$1.isDirectory
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            
            self.fileItems = items
            return items
        } catch {
            self.connectionError = "Ordnerauflistung fehlgeschlagen: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Checks if a file exists on the server
    public func fileExists(atPath path: String) async -> Bool {
        guard let manager = manager else { return false }
        do {
            // List the parent directory and check if the file name exists
            let parentPath = (path as NSString).deletingLastPathComponent
            let fileName = (path as NSString).lastPathComponent
            let items = try await manager.contentsOfDirectory(atPath: parentPath)
            return items.contains { $0.name == fileName }
        } catch {
            return false
        }
    }
    
    /// Creates a directory at path
    public func createDirectory(atPath path: String) async throws {
        guard let manager = manager else {
            throw NSError(domain: "SMBService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nicht verbunden"])
        }
        try await manager.createDirectory(atPath: path)
    }
    
    /// Uploads a local file to the remote path.
    public func uploadFile(localURL: URL, remotePath: String) async throws {
        guard let manager = manager else {
            throw NSError(domain: "SMBService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nicht verbunden"])
        }
        
        await MainActor.run {
            self.isTransferring = true
            self.transferProgress = 0.0
            self.currentTransferFile = localURL.lastPathComponent
        }
        
        defer {
            Task { @MainActor in
                self.isTransferring = false
                self.transferProgress = 0.0
                self.currentTransferFile = ""
            }
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.uploadItem(at: localURL, toPath: remotePath, progress: { bytesSent in
                Task { @MainActor in
                    self.transferProgress = bytesSent
                }
                return true // Continue upload
            }, completionHandler: { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }
    
    /// Downloads a remote file to a local URL.
    public func downloadFile(remotePath: String, localURL: URL) async throws {
        guard let manager = manager else {
            throw NSError(domain: "SMBService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nicht verbunden"])
        }
        
        await MainActor.run {
            self.isTransferring = true
            self.transferProgress = 0.0
            self.currentTransferFile = (remotePath as NSString).lastPathComponent
        }
        
        defer {
            Task { @MainActor in
                self.isTransferring = false
                self.transferProgress = 0.0
                self.currentTransferFile = ""
            }
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.downloadItem(atPath: remotePath, to: localURL, progress: { (bytesReceived, totalBytes) in
                let progress = Double(bytesReceived) / Double(totalBytes)
                Task { @MainActor in
                    self.transferProgress = progress
                }
                return true // Continue download
            }, completionHandler: { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }
}
