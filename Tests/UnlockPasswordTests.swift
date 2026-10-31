import Foundation
import Security

private final class MemoryPasswordStorage: UnlockPasswordStorage {
    var data: Data?
    var failWrites = false
    func read() throws -> Data? { data }
    func write(_ data: Data) throws {
        if failWrites { throw UnlockPassword.Failure.keychain(errSecInteractionNotAllowed) }
        self.data = data
    }
}

@main
struct UnlockPasswordTests {
    static func check(_ condition: Bool, file: StaticString = #file, line: UInt = #line) {
        precondition(condition, "password test failed", file: file, line: line)
    }

    static func main() throws {
        let memory = MemoryPasswordStorage()
        let passwords = UnlockPassword(storage: memory)
        check(try !passwords.hasPassword())
        check(try !passwords.verify("anything-valid"))

        check(UnlockPassword.validationError("short") == .length)
        check(UnlockPassword.validationError(String(repeating: "a", count: 129)) == .length)
        check(UnlockPassword.validationError("abcd\nefgh") == .printableASCII)
        check(UnlockPassword.validationError("암호-password") == .printableASCII)
        check(UnlockPassword.validationError(" spaces accepted! ") == nil)
        check(UnlockPassword.validationError(String(repeating: "A", count: 128)) == nil)

        // Independent PBKDF2-HMAC-SHA256 vector generated with Python hashlib:
        // password test-password, salt bytes 0...31, 210000 iterations, 32 bytes.
        memory.data = Data(#"{"version":1,"iterations":210000,"salt":"AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=","digest":"+uLU326vDrQt8uVhr0ivJKFBGly4Z3lHH6jgYu6V88o="}"#.utf8)
        check(try passwords.verify("test-password"))
        check(try !passwords.verify("test-passwore"))

        try passwords.setPassword("first-password !")
        check(try passwords.hasPassword())
        check(try passwords.verify("first-password !"))
        check(try !passwords.verify("first-password ?"))
        check(try !passwords.verify("first-password ! "))
        check(try !passwords.verify("first-password !\n"))
        let original = memory.data!
        check(!String(decoding: original, as: UTF8.self).contains("first-password"))

        // Generating the same password again must use a fresh random salt.
        try passwords.setPassword("first-password !")
        check(memory.data != original)
        check(try passwords.verify("first-password !"))

        let retained = memory.data
        memory.failWrites = true
        do {
            try passwords.setPassword("new-password !")
            assertionFailure("failed update must throw")
        } catch UnlockPassword.Failure.keychain { }
        check(memory.data == retained)
        check(try passwords.verify("first-password !"))
        memory.failWrites = false

        do {
            try passwords.setPassword("short")
            assertionFailure("invalid password must throw")
        } catch UnlockPassword.Failure.invalidPassword(.length) { }
        check(memory.data == retained)

        try passwords.setPassword("replacement-password")
        check(try passwords.verify("replacement-password"))
        check(try !passwords.verify("first-password !"))

        // Invalid bytes, version, salt size and an attacker-selected work factor
        // all fail closed before attempting password verification.
        let valid = memory.data!
        let object = try JSONSerialization.jsonObject(with: valid) as! [String: Any]
        var corruptions = [Data("not json".utf8), Data(repeating: 65, count: 2049)]
        for (key, value) in [("version", 99 as Any), ("iterations", 4_000_000_000 as Any),
                             ("salt", Data([1, 2]).base64EncodedString() as Any),
                             ("digest", Data([3]).base64EncodedString() as Any)] {
            var bad = object
            bad[key] = value
            corruptions.append(try JSONSerialization.data(withJSONObject: bad))
        }
        for bad in corruptions {
            memory.data = bad
            do {
                _ = try passwords.hasPassword()
                assertionFailure("corrupt credential must be rejected")
            } catch UnlockPassword.Failure.invalidStoredCredential { }
            do {
                _ = try passwords.verify("replacement-password")
                assertionFailure("corrupt credential cannot unlock")
            } catch UnlockPassword.Failure.invalidStoredCredential { }
        }
        print("PASS: password validation, correct/wrong verification, random salt, atomic replacement failure, corruption rejection (memory storage only)")
    }
}
