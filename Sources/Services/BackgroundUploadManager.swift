import Foundation
import BackgroundTasks
import UserNotifications

public class BackgroundUploadManager: ObservableObject {
    public static let shared = BackgroundUploadManager()
    
    public static let taskId = "com.smbbackup.upload"
    private let autoBackupKey = "com.smbbackup.autoBackupEnabled"
    private let scheduledTimeKey = "com.smbbackup.scheduledTime"
    
    @Published public var autoBackupEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoBackupEnabled, forKey: autoBackupKey)
            if autoBackupEnabled {
                scheduleBackgroundProcessing()
                // scheduleLocalNotification() // Removed to allow silent background execution
            } else {
                cancelAllTasksAndNotifications()
            }
        }
    }
    
    @Published public var scheduledTime: Date {
        didSet {
            UserDefaults.standard.set(scheduledTime, forKey: scheduledTimeKey)
            if autoBackupEnabled {
                scheduleBackgroundProcessing()
                // scheduleLocalNotification() // Removed to allow silent background execution
            }
        }
    }
    
    private init() {
        // Default values: disabled, 22:00 (10 PM)
        self.autoBackupEnabled = UserDefaults.standard.bool(forKey: autoBackupKey)
        
        if let savedTime = UserDefaults.standard.object(forKey: scheduledTimeKey) as? Date {
            self.scheduledTime = savedTime
        } else {
            var components = DateComponents()
            components.hour = 22
            components.minute = 0
            self.scheduledTime = Calendar.current.date(from: components) ?? Date()
        }
    }
    
    /// Requests notification permissions from the user
    public func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Fehler beim Beantragen von Benachrichtigungs-Berechtigungen: \(error)")
            return false
        }
    }
    
    /// Cancels background jobs and notifications
    private func cancelAllTasksAndNotifications() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["com.smbbackup.daily_notification"])
    }
    
    /// Schedules a background processing task in iOS.
    public func scheduleBackgroundProcessing() {
        // Cancel existing scheduled task before rescheduling
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskId)
        
        let request = BGProcessingTaskRequest(identifier: Self.taskId)
        
        // Calculate when the task should run (earliest start date)
        request.earliestBeginDate = calculateNextOccurrence(of: scheduledTime)
        
        // Backups require network and should ideally happen when charging
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Hintergrundaufgabe erfolgreich registriert für: \(request.earliestBeginDate?.description ?? "unbekannt")")
        } catch {
            print("Konnte Hintergrundaufgabe nicht registrieren: \(error.localizedDescription)")
        }
    }
    
    /// Schedules a daily Local Notification to prompt the user at the exact scheduled time.
    public func scheduleLocalNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["com.smbbackup.daily_notification"])
        
        let content = UNMutableNotificationContent()
        content.title = "Automatisches SMB-Backup"
        content.body = "Tippe hier, um das tägliche Backup deiner Fotos auf den SMB-Server zu starten."
        content.sound = .default
        
        // Extract hour and minute components from the scheduled time
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        
        // Create trigger that fires every day at this exact time
        let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "com.smbbackup.daily_notification",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Konnte Benachrichtigung nicht planen: \(error)")
            } else {
                print("Lokale Benachrichtigung geplant für jeden Tag um \(timeComponents.hour ?? 0):\(timeComponents.minute ?? 0)")
            }
        }
    }
    
    /// Helper to compute the next occurrence of a time (e.g. today at 22:00, or tomorrow at 22:00 if today is past it)
    private func calculateNextOccurrence(of time: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var targetComponents = calendar.dateComponents([.year, .month, .day], from: now)
        targetComponents.hour = timeComponents.hour
        targetComponents.minute = timeComponents.minute
        targetComponents.second = 0
        
        guard let targetDate = calendar.date(from: targetComponents) else {
            return now.addingTimeInterval(3600) // Fallback: in 1 hour
        }
        
        if targetDate > now {
            return targetDate
        } else {
            // Target is in the past for today, schedule for tomorrow
            return calendar.date(byAdding: .day, value: 1, to: targetDate) ?? now.addingTimeInterval(24 * 3600)
        }
    }
}
