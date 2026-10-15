import Foundation
import Security
import CryptoKit

/**
 * ŠankFinder SecureStorage
 * Strojno pospešeno šifriranje AES-256-GCM (Apple Silicon / Secure Enclave)
 * ter varna hramba ključev in identifikatorjev v iOS Keychain.
 */
class SecureStorage {
    static let shared = SecureStorage()
    
    private let masterKeyTag = "com.sankfinder.master_encryption_key"
    private let sharedSecretHex = "0e249416dd0bbb1efcfa3c763e2eaad4d2f700cdbcf2bcc3d71fc6223f0f9571"
    
    private var cachedKey: SymmetricKey?
    
    private init() {}
    
    // MARK: - AES-256-GCM Master Key (Keychain)
    
    func getOrCreateMasterKey() -> SymmetricKey {
        if let key = cachedKey { return key }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: masterKeyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let keyData = item as? Data {
            let key = SymmetricKey(data: keyData)
            self.cachedKey = key
            return key
        }
        
        // Ustvari nov varen 256-bitni ključ
        let newKey = SymmetricKey(size: .bits256)
        let rawKeyData = newKey.withUnsafeBytes { Data($0) }
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: masterKeyTag,
            kSecValueData as String: rawKeyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)
        
        self.cachedKey = newKey
        return newKey
    }
    
    // MARK: - AES-256-GCM Šifriranje in Dešifriranje
    
    func encrypt(data: Data) throws -> Data {
        let key = getOrCreateMasterKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "SecureStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Šifriranje ni uspelo"])
        }
        return combined
    }
    
    func decrypt(combinedData: Data) throws -> Data {
        let key = getOrCreateMasterKey()
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Varna hramba nizev v Keychain (npr. sankfinder_device_id)
    
    func saveString(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
    
    func getString(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    // MARK: - HMAC-SHA256 Podpisovanje zahtevkov (Anti-Replay)
    
    func generateSignature(timestamp: Int64, deviceId: String) -> String {
        let payload = "\(deviceId):\(timestamp)"
        let secretData = sharedSecretHex.data(using: .utf8) ?? Data()
        let key = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return signature.map { String(format: "%02hhx", $0) }.joined()
    }
}
