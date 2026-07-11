import Foundation

public struct BackupLog: Codable, Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let filesUploadedCount: Int
    public let totalBytesUploaded: Int64
    public let status: LogStatus
    public let errorMessage: String?
    public let uploadedFiles: [String]
    
    public enum LogStatus: String, Codable {
        case success = "Success"
        case failure = "Error"
    }
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), filesUploadedCount: Int, totalBytesUploaded: Int64, status: LogStatus, errorMessage: String? = nil, uploadedFiles: [String] = []) {
        self.id = id
        self.timestamp = timestamp
        self.filesUploadedCount = filesUploadedCount
        self.totalBytesUploaded = totalBytesUploaded
        self.status = status
        self.errorMessage = errorMessage
        self.uploadedFiles = uploadedFiles
    }
    
    private static let logsDefaultsKey = "com.smbbackup.backupLogs"
    
    public static func loadAll() -> [BackupLog] {
        guard let data = UserDefaults.standard.data(forKey: logsDefaultsKey),
              let logs = try? JSONDecoder().decode([BackupLog].self, from: data) else {
            return []
        }
        // Return sorted by date (newest first)
        return logs.sorted { $0.timestamp > $1.timestamp }
    }
    
    public static func saveAll(_ logs: [BackupLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: logsDefaultsKey)
        }
    }
    
    public static func addLog(_ log: BackupLog) {
        var logs = loadAll()
        logs.append(log)
        // Keep only last 100 logs to prevent UserDefaults bloating
        if logs.count > 100 {
            logs.sort { $0.timestamp > $1.timestamp }
            logs = Array(logs.prefix(100))
        }
        saveAll(logs)
    }
    
    public static func clearLogs() {
        UserDefaults.standard.removeObject(forKey: logsDefaultsKey)
    }
}
