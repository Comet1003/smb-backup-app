import Foundation
import Security

public class KeychainHelper {
    public static let shared = KeychainHelper()
    private init() {}
    
    private let serviceName = "com.smbbackup.password"
    
    public func savePassword(_ password: String, forHost host: String) {
        guard let data = password.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: host
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // Item exists, update it
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        } else if status == errSecItemNotFound {
            // Item does not exist, add it
            var newQuery = query
            newQuery[kSecValueData as String] = data
            // Accessible when device is unlocked (best practice)
            newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(newQuery as CFDictionary, nil)
        }
    }
    
    public func getPassword(forHost host: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: host,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    public func deletePassword(forHost host: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: host
        ]
        SecItemDelete(query as CFDictionary)
    }
}
