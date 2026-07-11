import SwiftUI

public struct MainTabView: View {
    @StateObject private var smbService = SMBService()
    @StateObject private var backupService = MediaBackupService()
    
    public init() {
        // Customize TabBar appearance for dark theme
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
    }
}
