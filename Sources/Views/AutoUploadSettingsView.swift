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
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.1, green: 0.12, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Active Backup Progress Panel
                        if backupService.isBackingUp {
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Sicherung läuft...")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(backupService.currentFilename)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(backupService.currentBackupIndex) / \(backupService.totalToBackup)")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(.blue)
                                }
                                
                                ProgressView(value: Double(backupService.currentBackupIndex), total: Double(max(1, backupService.totalToBackup)))
                                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(15)
                            .padding(.horizontal)
                        }
                        
                        // Configuration Section
                        VStack(spacing: 16) {
                            HStack {
                                Text("EINSTELLUNGEN")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.blue)
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
                                        .foregroundColor(.gray)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Time Picker
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tägliche Uhrzeit")
                                        .foregroundColor(.white)
                                        .bold()
                                    Text("Geplante Zeit für das Backup")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                DatePicker("", selection: $bgManager.scheduledTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
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
                                .background(backupService.isBackingUp ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .bold()
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
                                .background(Color.red.opacity(0.15))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                                .bold()
                            }
                        }
                        .padding(.horizontal)
                        
                        // Backup Logs Section
                        VStack(spacing: 12) {
                            HStack {
                                Text("PROTOKOLLE (\(logs.count))")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.blue)
                                Spacer()
                                if !logs.isEmpty {
                                    Button(action: {
                                        showingClearLogsConfirmation = true
                                    }) {
                                        Text("Löschen")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                            if logs.isEmpty {
                                Text("Bisher keine Backup-Protokolle vorhanden.")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.02))
                                    .cornerRadius(15)
                                    .padding(.horizontal)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(logs) { log in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Circle()
                                                    .fill(log.status == .success ? Color.green : Color.red)
                                                    .frame(width: 8, height: 8)
                                                
                                                Text(formatDate(log.timestamp))
                                                    .font(.subheadline)
                                                    .bold()
                                                    .foregroundColor(.white)
                                                
                                                Spacer()
                                                
                                                Text(log.status.rawValue)
                                                    .font(.caption)
                                                    .bold()
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(log.status == .success ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                                    .foregroundColor(log.status == .success ? .green : .red)
                                                    .cornerRadius(5)
                                            }
                                            
                                            HStack {
                                                Text("Hochgeladen: \(log.filesUploadedCount) Dateien")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                Spacer()
                                                Text(formatBytes(log.totalBytesUploaded))
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            if let error = log.errorMessage {
                                                Text("Fehler: \(error)")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                                    .lineLimit(2)
                                                    .padding(.top, 2)
                                            }
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.03))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
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
            // Request permission & start backup process
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
