import SwiftUI

public struct ConnectionSetupView: View {
    @ObservedObject var smbService: SMBService
    
    @State private var host = ""
    @State private var share = ""
    @State private var path = "/"
    @State private var username = ""
    @State private var password = ""
    
    @State private var testResultSuccess: Bool? = nil
    @State private var testResultMessage = ""
    @State private var isTesting = false
    @State private var showSaveSuccess = false
    
    public init(smbService: SMBService) {
        self.smbService = smbService
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Flowing neon/glassmorphism background
                Color(red: 0.04, green: 0.04, blue: 0.08)
                    .ignoresSafeArea()
                
                // Top-left soft glowing blue orb
                Circle()
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: 350, height: 350)
                    .blur(radius: 90)
                    .offset(x: -120, y: -250)
                
                // Bottom-right soft glowing purple orb
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: 140, y: 200)
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Title / Header Card
                        VStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 55))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 5)
                            
                            Text("SMB Server Verbindung")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            
                            Text("Richte die Verbindung zu deinem Netzwerkspeicher ein, um Backups zu ermöglichen.")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        .padding(.top, 25)
                        
                        // Credentials Card with glassmorphism
                        VStack(spacing: 18) {
                            HStack {
                                Text("SERVER-DATEN")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.cyan)
                                Spacer()
                            }
                            
                            customTextField(title: "Server IP / Hostname", text: $host, icon: "network", placeholder: "z.B. 192.168.178.10")
                            customTextField(title: "Freigabename (Share)", text: $share, icon: "folder.badge.share", placeholder: "z.B. Photos")
                            customTextField(title: "Zielordner auf Server", text: $path, icon: "folder.fill", placeholder: "z.B. /Backup (Standard: /)")
                            customTextField(title: "Benutzername", text: $username, icon: "person.fill", placeholder: "Benutzername")
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Passwort")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.8))
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.cyan)
                                        .frame(width: 25)
                                    SecureField("Passwort", text: $password)
                                        .foregroundColor(.white)
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }
                        .padding(22)
                        .background(.ultraThinMaterial) // iOS Native blur
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 12)
                        .padding(.horizontal)
                        
                        // Testing Status or Messages
                        if isTesting {
                            ProgressView("Verbindung wird getestet...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                .foregroundColor(.white)
                                .padding()
                        } else if let success = testResultSuccess {
                            HStack(spacing: 12) {
                                Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.title2)
                                    .foregroundColor(success ? .green : .red)
                                Text(testResultMessage)
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                    .bold()
                                Spacer()
                            }
                            .padding(16)
                            .background(success ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(success ? Color.green.opacity(0.2) : Color.red.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            // Test Button
                            Button(action: {
                                performTestConnection()
                            }) {
                                HStack {
                                    Image(systemName: "bolt.horizontal.fill")
                                    Text("Verbindung testen")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .bold()
                            }
                            .disabled(isTesting || host.isEmpty || share.isEmpty)
                            
                            // Save & Connect Button
                            Button(action: {
                                saveAndConnect()
                            }) {
                                HStack {
                                    if smbService.isConnecting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 5)
                                    } else {
                                        Image(systemName: "checkmark.seal.fill")
                                    }
                                    Text(smbService.isConnected ? "Gespeichert & Verbunden" : "Speichern & Verbinden")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: smbService.isConnected ? [.green, .emeraldColor] : [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .bold()
                                .shadow(color: (smbService.isConnected ? Color.green : Color.blue).opacity(0.35), radius: 12, x: 0, y: 5)
                            }
                            .disabled(smbService.isConnecting || host.isEmpty || share.isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("SMB Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if smbService.isConnected {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Verbunden")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Getrennt")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .onAppear {
                loadConfig()
            }
        }
    }
    
    // Custom TextField Helper with glassmorphism style
    private func customTextField(title: String, text: Binding<String>, icon: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .bold()
                .foregroundColor(.white.opacity(0.8))
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.cyan)
                    .frame(width: 25)
                TextField(placeholder, text: text)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    // Load config from settings
    private func loadConfig() {
        let config = SMBConnectionConfig.load()
        self.host = config.host
        self.share = config.share
        self.path = config.path
        self.username = config.username
        self.password = KeychainHelper.shared.getPassword(forHost: config.host) ?? ""
    }
    
    // Test SMB Connection
    private func performTestConnection() {
        isTesting = true
        testResultSuccess = nil
        
        let config = SMBConnectionConfig(host: host, share: share, path: path, username: username)
        
        Task {
            let result = await smbService.testConnection(config: config, password: password)
            isTesting = false
            testResultSuccess = result.success
            testResultMessage = result.message
        }
    }
    
    // Save Config and Connect
    private func saveAndConnect() {
        let config = SMBConnectionConfig(host: host, share: share, path: path, username: username)
        config.save()
        KeychainHelper.shared.savePassword(password, forHost: host)
        
        Task {
            let success = await smbService.connect(config: config)
            if success {
                testResultSuccess = true
                testResultMessage = "Verbindung erfolgreich hergestellt!"
            } else {
                testResultSuccess = false
                testResultMessage = smbService.connectionError ?? "Konnte nicht verbinden."
            }
        }
    }
}

// Helper colors for gradients
extension Color {
    static let emeraldColor = Color(red: 0.05, green: 0.75, blue: 0.45)
}
