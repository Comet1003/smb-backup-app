import SwiftUI
import Combine
import AMSMB2

public struct MainTabView: View {
    // Using StateObject is safe if we don't initialize @MainActor properties inside structural code before the app is fully ready.
    // However, to be 100% crash-safe under iOS 17/18 strict actor isolation, we can pass them down or initialize them lazily.
    @StateObject private var smbService = SMBService()
    @StateObject private var backupService = MediaBackupService()
    
    public init() {
        // Customize TabBar appearance for dark theme safely
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    public var body: some View {
        TabView {
            ConnectionSetupView(smbService: smbService)
                .tabItem {
                    Label("SMB Setup", systemImage: "server.rack")
                }
            
            FileBrowserView(smbService: smbService)
                .tabItem {
                    Label("Dateien", systemImage: "folder.fill")
                }
            
            AutoUploadSettingsView(smbService: smbService, backupService: backupService)
                .tabItem {
                    Label("Auto-Backup", systemImage: "arrow.clockwise.icloud.fill")
                }
        }
        .accentColor(.blue)
        .preferredColorScheme(.dark) // Lock app to modern dark mode
        .onAppear {
            autoConnect()
        }
    }
    
    private func autoConnect() {
        guard !smbService.isConnected && !smbService.isConnecting else { return }
        let config = SMBConnectionConfig.load()
        guard !config.host.isEmpty && !config.share.isEmpty else { return }
        
        Task {
            _ = await smbService.connect(config: config)
        }
    }
}
