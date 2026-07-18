import Foundation

public struct SMBConnectionConfig: Codable, Equatable {
    public var host: String
    public var share: String
    public var path: String
    public var username: String
    
    public init(host: String = "192.168.178.158", share: String = "Share", path: String = "/Iphone_Bilder", username: String = "Benjamin") {
        self.host = host
        self.share = share
        self.path = path.isEmpty ? "/Iphone_Bilder" : (path.hasPrefix("/") ? path : "/" + path)
        self.username = username
    }
    
    /// The formatted SMB URL, e.g. "smb://192.168.1.10"
    public var serverURL: URL? {
        var cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ensure no prefix like smb:// is double-added
        if cleanHost.lowercased().hasPrefix("smb://") {
            cleanHost = String(cleanHost.dropFirst(6))
        }
        return URL(string: "smb://\(cleanHost)")
    }
    
    // Key for UserDefaults
    private static let userDefaultsKey = "com.smbbackup.connectionConfig"
    
    public static func load() -> SMBConnectionConfig {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(SMBConnectionConfig.self, from: data) else {
            return SMBConnectionConfig()
        }
        return config
    }
    
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: SMBConnectionConfig.userDefaultsKey)
        }
    }
}
