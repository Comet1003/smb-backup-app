import SwiftUI
import BackgroundTasks

@main
struct SMBBackupApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Register the background processing task handler
        // Note: This MUST be done during app launch before any view appears
        registerBackgroundTask()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .background:
                        // Make sure the background job is scheduled when the app goes to background
                        if BackgroundUploadManager.shared.autoBackupEnabled {
                            BackgroundUploadManager.shared.scheduleBackgroundProcessing()
                        }
                    case .active:
                        // Request notification permissions when app becomes active (good timing)
                        Task {
                            _ = await BackgroundUploadManager.shared.requestNotificationPermission()
                        }
                    default:
                        break
                    }
                }
        }
    }
    
    private func registerBackgroundTask() {
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundUploadManager.taskId,
            using: nil
        ) { task in
            // Handle the background execution
            if let processingTask = task as? BGProcessingTask {
                self.handleBackgroundUpload(task: processingTask)
            }
        }
        
        if registered {
            print("Hintergrund-Task erfolgreich bei iOS registriert.")
        } else {
            print("Konnte Hintergrund-Task nicht bei iOS registrieren.")
        }
    }
    
    /// Executor for the scheduled background task
    private func handleBackgroundUpload(task: BGProcessingTask) {
        // 1. Immediately schedule the next task so the cycle continues daily
        BackgroundUploadManager.shared.scheduleBackgroundProcessing()
        
        // 2. Setup task cancellation/expiration hook
        var isCancelled = false
        task.expirationHandler = {
            isCancelled = true
        }
        
        // 3. Execute the backup on the MainActor (required for our services)
        Task { @MainActor in
            let smbService = SMBService()
            let backupService = MediaBackupService()
            let config = SMBConnectionConfig.load()
            
            let result = await backupService.performBackup(
                smbService: smbService,
                config: config,
                expirationHandler: { isCancelled }
            )
            
            // Mark task as successful or failed
            task.setTaskCompleted(success: result.success)
        }
    }
}
