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
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.1, green: 0.12, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Title / Header Card
                        VStack(spacing: 8) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                                .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
                            
                            Text("SMB Server Verbindung")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            
                            Text("Richte die Verbindung zu deinem Netzwerkspeicher ein, um Backups zu ermöglichen.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                        
                        // Credentials Card
                        VStack(spacing: 16) {
                            HStack {
                                Text("SERVER-DATEN")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.blue)
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
                                        .foregroundColor(.blue)
                                        .frame(width: 25)
                                    SecureField("Passwort", text: $password)
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 10)
                        .padding(.horizontal)
                        
                        // Testing Status or Messages
                        if isTesting {
                            ProgressView("Verbindung wird getestet...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .foregroundColor(.white)
                                .padding()
                        } else if let success = testResultSuccess {
                            HStack {
                                Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(success ? .green : .red)
                                Text(testResultMessage)
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding()
                            .background(success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            .cornerRadius(10)
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
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(12)
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
                                .background(smbService.isConnected ? Color.green : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .bold()
                                .shadow(color: (smbService.isConnected ? Color.green : Color.blue).opacity(0.3), radius: 10, x: 0, y: 5)
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
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Verbunden")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Getrennt")
                                .font(.caption)
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
    
    // Custom TextField Helper
    private func customTextField(title: String, text: Binding<String>, icon: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .bold()
                .foregroundColor(.white.opacity(0.8))
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 25)
                TextField(placeholder, text: text)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
