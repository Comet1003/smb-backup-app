import SwiftUI
import BackgroundTasks

@main
struct SMBBackupApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // Register background task safely AFTER app is visible
                    registerBackgroundTask()
                }
                .onChange(of: scenePhase, perform: { newPhase in
                    switch newPhase {
                    case .background:
                        if BackgroundUploadManager.shared.autoBackupEnabled {
                            BackgroundUploadManager.shared.scheduleBackgroundProcessing()
                        }
                    case .active:
                        // Delay notification request to avoid crash on first launch
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            Task {
                                _ = await BackgroundUploadManager.shared.requestNotificationPermission()
                            }
                        }
                    default:
                        break
                    }
                })
        }
    }

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundUploadManager.taskId,
            using: nil
        ) { task in
            if let processingTask = task as? BGProcessingTask {
                handleBackgroundUpload(task: processingTask)
            }
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
