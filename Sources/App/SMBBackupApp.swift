import SwiftUI
import BackgroundTasks

@main
struct SMBBackupApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register the background processing task handler
        // Note: This MUST be done during app launch before any view appears (in init)
        registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onChange(of: scenePhase, perform: { newPhase in
                    switch newPhase {
                    case .background:
                        if BackgroundUploadManager.shared.autoBackupEnabled {
                            BackgroundUploadManager.shared.scheduleBackgroundProcessing()
                        }
                    case .active:
                        // Request notification permissions when app becomes active
                        Task {
                            _ = await BackgroundUploadManager.shared.requestNotificationPermission()
                        }
                    default:
                        break
                    }
                })
        }
    }

    private func registerBackgroundTask() {
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundUploadManager.taskId,
            using: nil
        ) { task in
            if let processingTask = task as? BGProcessingTask {
                handleBackgroundUpload(task: processingTask)
            }
        }
        if registered {
            print("Hintergrund-Task erfolgreich registriert.")
        } else {
            print("Fehler bei der Registrierung des Hintergrund-Tasks.")
        }
    }

    private func handleBackgroundUpload(task: BGProcessingTask) {
        BackgroundUploadManager.shared.scheduleBackgroundProcessing()

        var isCancelled = false
        task.expirationHandler = {
            isCancelled = true
        }

        Task { @MainActor in
            let smbService = SMBService()
            let backupService = MediaBackupService()
            let config = SMBConnectionConfig.load()

            let result = await backupService.performBackup(
                smbService: smbService,
                config: config,
                expirationHandler: { isCancelled }
            )

            task.setTaskCompleted(success: result.success)
        }
    }
}
