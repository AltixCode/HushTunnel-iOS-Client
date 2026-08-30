import Foundation
import Combine
import Security

@MainActor
public final class AuthStore: ObservableObject {
    public static let shared = AuthStore()

    @Published public private(set) var token: String?
    @Published public private(set) var email: String?
    @Published public private(set) var role: String?
    @Published public private(set) var isAuthenticated: BooleanLiteralType = false

    private let tokenKey = "com.shadowlink.auth.token"
    private let emailKey = "com.shadowlink.auth.email"
    private let roleKey = "com.shadowlink.auth.role"

    private init() {
        loadSession()
    }

    public func loadSession() {
        let defaults = UserDefaults.standard
        let savedToken = defaults.string(forKey: tokenKey)
        let savedEmail = defaults.string(forKey: emailKey)
        let savedRole = defaults.string(forKey: roleKey)

        if let savedToken, !savedToken.isEmpty {
            self.token = savedToken
            self.email = savedEmail
            self.role = savedRole ?? "USER"
            self.isAuthenticated = true
        } else {
            self.token = nil
            self.email = nil
            self.role = nil
            self.isAuthenticated = false
        }
    }

    public func saveSession(token: String, email: String, role: String) {
        let defaults = UserDefaults.standard
        defaults.set(token, forKey: tokenKey)
        defaults.set(email, forKey: emailKey)
        defaults.set(role, forKey: roleKey)

        self.token = token
        self.email = email
        self.role = role
        self.isAuthenticated = true
    }

    public func updateRole(_ role: String) {
        let defaults = UserDefaults.standard
        defaults.set(role, forKey: roleKey)
        self.role = role
    }

    public func logout() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: emailKey)
        defaults.removeObject(forKey: roleKey)

        self.token = nil
        self.email = nil
        self.role = nil
        self.isAuthenticated = false
    }
}
