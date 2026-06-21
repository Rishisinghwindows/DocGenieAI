import LocalAuthentication

@MainActor
@Observable
final class VaultService {
    static let shared = VaultService()
    private(set) var isUnlocked = false
    private let context = LAContext()

    private init() {}

    var isBiometricAvailable: Bool {
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometricType: LABiometryType {
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedReason = "Access your secure document vault"
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Secure Vault")
            isUnlocked = success
            return success
        } catch {
            // Fall back to passcode
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Secure Vault")
                isUnlocked = success
                return success
            } catch {
                return false
            }
        }
    }

    func lock() {
        isUnlocked = false
    }
}
