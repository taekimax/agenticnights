import Foundation
import CommonCrypto
import Security
import LocalAuthentication

/// The privacy cover has its own password; it never reads the macOS login password.
/// Only a salted PBKDF2 verifier is stored, in Keychain rather than preferences.
final class UnlockPassword {
    enum ValidationError: Error, Equatable {
        case length
        case printableASCII
    }

    enum Failure: Error {
        case invalidPassword(ValidationError)
        case invalidStoredCredential
        case keychain(OSStatus)
        case random(OSStatus)
        case derivation(Int32)
    }

    private struct Credential: Codable {
        let version: Int
        let iterations: UInt32
        let salt: Data
        let digest: Data
    }

    private static let iterations: UInt32 = 210_000
    private static let saltLength = 32
    private static let digestLength = 32
    private let storage: UnlockPasswordStorage

    init(storage: UnlockPasswordStorage = KeychainUnlockPasswordStorage()) {
        self.storage = storage
    }

    /// The physical-key unlock path does not run an input method editor.
    /// Spaces and printable ASCII punctuation are accepted; controls and IME text are not.
    static func validationError(_ password: String) -> ValidationError? {
        let bytes = Array(password.utf8)
        guard (8...128).contains(bytes.count) else { return .length }
        guard bytes.allSatisfy({ (32...126).contains($0) }) else { return .printableASCII }
        return nil
    }

    /// Corrupt/unreadable material is an error, never an implicit default password.
    func hasPassword() throws -> Bool {
        guard let data = try storage.read() else { return false }
        _ = try Self.decode(data)
        return true
    }

    /// Keychain update is atomic. A failed replacement leaves the existing verifier intact.
    func setPassword(_ password: String) throws {
        if let error = Self.validationError(password) { throw Failure.invalidPassword(error) }
        var salt = [UInt8](repeating: 0, count: Self.saltLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt)
        guard status == errSecSuccess else { throw Failure.random(status) }
        let saltData = Data(salt)
        let digest = try Self.derive(password, salt: saltData)
        let credential = Credential(version: 1, iterations: Self.iterations, salt: saltData, digest: digest)
        try storage.write(JSONEncoder().encode(credential))
    }

    func verify(_ password: String) throws -> Bool {
        guard let data = try storage.read() else { return false }
        let credential = try Self.decode(data)
        guard Self.validationError(password) == nil else { return false }
        let candidate = try Self.derive(password, salt: credential.salt)
        // Both digests have a fixed length; examine every byte before deciding.
        var difference: UInt8 = 0
        for (a, b) in zip(candidate, credential.digest) { difference |= a ^ b }
        return difference == 0
    }

    private static func decode(_ data: Data) throws -> Credential {
        guard data.count <= 2048,
              let value = try? JSONDecoder().decode(Credential.self, from: data),
              value.version == 1, value.iterations == iterations,
              value.salt.count == saltLength, value.digest.count == digestLength else {
            throw Failure.invalidStoredCredential
        }
        return value
    }

    private static func derive(_ password: String, salt: Data) throws -> Data {
        var result = [UInt8](repeating: 0, count: digestLength)
        let status = password.withCString { characters in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), characters, password.utf8.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations, &result, result.count)
            }
        }
        guard status == kCCSuccess else { throw Failure.derivation(status) }
        return Data(result)
    }
}

/// Injectable only so tests can exercise failure paths without touching user Keychain data.
protocol UnlockPasswordStorage {
    func read() throws -> Data?
    func write(_ data: Data) throws
}

struct KeychainUnlockPasswordStorage: UnlockPasswordStorage {
    private var query: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: "com.tk.agenticnights.unlock",
         kSecAttrAccount: "privacy-cover-password"]
    }

    func read() throws -> Data? {
        var request = query
        request[kSecReturnData] = true
        request[kSecMatchLimit] = kSecMatchLimitOne
        // A locked cover must report an unavailable credential instead of opening
        // an unrelated Keychain authorization dialog behind the blackout.
        let context = LAContext()
        context.interactionNotAllowed = true
        request[kSecUseAuthenticationContext] = context
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw UnlockPassword.Failure.keychain(status) }
        guard let data = result as? Data else { throw UnlockPassword.Failure.invalidStoredCredential }
        return data
    }

    func write(_ data: Data) throws {
        let attributes: [CFString: Any] = [kSecValueData: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            item[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            item[kSecAttrLabel] = "agenticnights screen unlock"
            status = SecItemAdd(item as CFDictionary, nil)
            // Another instance may have created it between update and add.
            if status == errSecDuplicateItem {
                status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            }
        }
        guard status == errSecSuccess else { throw UnlockPassword.Failure.keychain(status) }
    }
}
