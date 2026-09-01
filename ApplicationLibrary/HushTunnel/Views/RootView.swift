import SwiftUI

public struct RootView: View {
    @ObservedObject var authStore = AuthStore.shared
    @ObservedObject var lang = LanguageManager.shared

    public init() {}

    public var body: some View {
        Group {
            if authStore.isAuthenticated {
                if authStore.role == "RESELLER" {
                    ResellerHomeView()
                } else if authStore.role == "ADMIN" {
                    AdminAlertView()
                } else {
                    UserHomeView()
                }
            } else {
                AuthView()
            }
        }
        .environment(\.layoutDirection, lang.layoutDirection)
    }
}

public struct AdminAlertView: View {
    @ObservedObject var authStore = AuthStore.shared

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("Admin Account Detected")
                .font(.title2)
                .fontWeight(.bold)

            Text("Admin accounts must use the web dashboard at hushtunnel.com to manage the infrastructure and billing.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Log Out") {
                authStore.logout()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.top, 16)
        }
        .padding(32)
    }
}
