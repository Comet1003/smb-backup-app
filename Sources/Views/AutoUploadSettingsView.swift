import SwiftUI

public struct AutoUploadSettingsView: View {
    @ObservedObject var smbService: SMBService
    @ObservedObject var backupService: MediaBackupService
    @ObservedObject var bgManager = BackgroundUploadManager.shared
    
    @State private var logs: [BackupLog] = []
    @State private var showingResetConfirmation = false
    @State private var showingClearLogsConfirmation = false
    
    public init(smbService: SMBService, backupService: MediaBackupService) {
        self.smbService = smbService
        self.backupService = backupService
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Background neon glow
                Color(red: 0.04, green: 0.04, blue: 0.08)
                    .ignoresSafeArea()
                
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: -100, y: 150)
                
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 350, height: 350)
                    .blur(radius: 90)
                    .offset(x: 120, y: -200)
                
                ScrollView {
                    VStack(spacing: 22) {
                        
                        // Active Backup Progress Panel
                        if backupService.isBackingUp {
                            VStack(spacing: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Sicherung läuft...")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(backupService.currentFilename)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(backupService.currentBackupIndex) / \(backupService.totalToBackup)")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(.cyan)
                                }
                                
                                ProgressView(value: Double(backupService.currentBackupIndex), total: Double(max(1, backupService.totalToBackup)))
                                    .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 10)
                            .padding(.horizontal)
                        }
                        
                        // Configuration Section (Glassmorphism)
                        VStack(spacing: 18) {
                            HStack {
                                Text("EINSTELLUNGEN")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.cyan)
                                Spacer()
                            }
                            
                            // Auto Backup Toggle
                            Toggle(isOn: $bgManager.autoBackupEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Automatischer Upload")
                                        .foregroundColor(.white)
                                        .bold()
                                    Text("Lädt täglich Fotos im Hintergrund hoch")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .cyan))
                            
                            Divider()
                                .background(Color.white.opacity(0.12))
                            
                            // Time Picker
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tägliche Uhrzeit")
                                        .foregroundColor(.white)
                                        .bold()
                                    Text("Geplante Zeit für das Backup")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                                DatePicker("", selection: $bgManager.scheduledTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                        }
                        .padding(22)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 15)
                        .padding(.horizontal)
                        
                        // Action Buttons Section
                        VStack(spacing: 12) {
                            // Run Backup Now Button
                            Button(action: {
                                runManualBackup()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Backup jetzt starten")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    backupService.isBackingUp ? 
                                    LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .bold()
                                .shadow(color: backupService.isBackingUp ? .clear : Color.blue.opacity(0.3), radius: 10, x: 0, y: 4)
                            }
                            .disabled(backupService.isBackingUp)
                            
                            // Reset Backup History Button
                            Button(action: {
                                showingResetConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Backup-Historie zurücksetzen")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.12))
                                .foregroundColor(.red)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                )
                                .bold()
                            }
                        }
                        .padding(.horizontal)
                        
                        // Backup Logs Section
                        VStack(spacing: 14) {
                            HStack {
                                Text("PROTOKOLLE (\(logs.count))")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.cyan)
                                Spacer()
                                if !logs.isEmpty {
                                    Button(action: {
                                        showingClearLogsConfirmation = true
                                    }) {
                                        Text("Löschen")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(.horizontal, 6)
                            
                            if logs.isEmpty {
                                Text("Bisher keine Backup-Protokolle vorhanden.")
                                    .foregroundColor(.white.opacity(0.4))
                                    .font(.subheadline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(18)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(logs) { log in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Circle()
                                                    .fill(log.status == .success ? Color.green : Color.red)
                                                    .frame(width: 8, height: 8)
                                                
                                                Text(formatDate(log.timestamp))
                                                    .font(.subheadline)
                                                    .bold()
                                                    .foregroundColor(.white)
                                                
                                                Spacer()
                                                
                                                Text(log.status == .success ? "Erfolg" : "Fehler")
                                                    .font(.caption)
                                                    .bold()
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(log.status == .success ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                                    .foregroundColor(log.status == .success ? .green : .red)
                                                    .cornerRadius(6)
                                            }
                                            
                                            HStack {
                                                Text("Dateien: \(log.filesUploadedCount) Bilder/Videos")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.6))
                                                Spacer()
                                                Text(formatBytes(log.totalBytesUploaded))
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                            
                                            if let error = log.errorMessage {
                                                Text("Fehler: \(error)")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                                    .lineLimit(2)
                                                    .padding(.top, 2)
                                            }
                                        }
                                        .padding(16)
                                        .background(Color.white.opacity(0.02))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .cornerRadius(24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Auto-Backup")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refreshLogs()
            }
            .alert("Sicherung zurücksetzen?", isPresented: $showingResetConfirmation) {
                Button("Abbrechen", role: .cancel) {}
                Button("Ja, zurücksetzen", role: .destructive) {
                    backupService.resetBackupHistory()
                }
            } message: {
                Text("Dadurch wird die Merkliste bereits hochgeladener Fotos gelöscht. Beim nächsten Backup werden alle Bilder erneut auf den Server übertragen.")
            }
            .alert("Protokolle löschen?", isPresented: $showingClearLogsConfirmation) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    BackupLog.clearLogs()
                    refreshLogs()
                }
            } message: {
                Text("Möchtest du wirklich alle Protokolleinträge löschen?")
            }
        }
    }
    
    // Helpers
    private func refreshLogs() {
        self.logs = BackupLog.loadAll()
    }
    
    private func runManualBackup() {
        let config = SMBConnectionConfig.load()
        
        Task {
            _ = await backupService.performBackup(
                smbService: smbService,
                config: config
            )
            refreshLogs()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
