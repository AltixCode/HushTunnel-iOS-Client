import SwiftUI

public struct AuthView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var authStore = AuthStore.shared
    @ObservedObject var lang = LanguageManager.shared

    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLanguagePicker = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header Brand
                        VStack(spacing: 8) {
                            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                                .font(.system(size: 64))
                                .foregroundColor(.accentColor)
                                .padding(.top, 32)

                            Text(BrandConfig.appName)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)

                            Text(isLogin ? lang.tr("auth.signIn") : lang.tr("auth.signUp"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Auth Card
                        VStack(spacing: 16) {
                            // Toggle Tabs
                            Picker("", selection: $isLogin) {
                                Text(lang.tr("auth.login")).tag(true)
                                Text(lang.tr("auth.register")).tag(false)
                            }
                            .pickerStyle(.segmented)
                            .padding(.bottom, 8)

                            // Error Banner
                            if let error = errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }

                            // Email Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text(lang.tr("auth.email"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("user@example.com", text: $email)
                                    .accessibilityIdentifier("hush.auth.email")
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding(12)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                            }

                            // Password Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text(lang.tr("auth.password"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField("••••••••", text: $password)
                                    .accessibilityIdentifier("hush.auth.password")
                                    .textContentType(isLogin ? .password : .newPassword)
                                    .padding(12)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                            }

                            // Submit Button
                            Button(action: handleAuth) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 8)
                                    }
                                    Text(isLogin ? lang.tr("auth.signIn") : lang.tr("auth.signUp"))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(isFormValid ? Color.accentColor : Color.gray.opacity(0.4))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || isLoading)
                            .accessibilityIdentifier("hush.auth.submit")
                            .padding(.top, 8)

                            if !isLogin {
                                VStack(spacing: 8) {
                                    Text(lang.tr("auth.legalNotice"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    HStack(spacing: 18) {
                                        Button(lang.tr("privacy.policy")) {
                                            if let url = URL(string: BrandConfig.privacyURL) { openURL(url) }
                                        }
                                        Button(lang.tr("terms.title")) {
                                            if let url = URL(string: BrandConfig.termsURL) { openURL(url) }
                                        }
                                    }
                                    .font(.caption)
                                }
                            }

                            // Toggle Switch
                            Button {
                                isLogin.toggle()
                                errorMessage = nil
                            } label: {
                                Text(isLogin ? lang.tr("auth.dontHaveAccount") + " " + lang.tr("auth.register") : lang.tr("auth.alreadyHaveAccount") + " " + lang.tr("auth.login"))
                                    .font(.footnote)
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.top, 4)
                        }
                        .padding(20)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 20)

                        Spacer()
                    }
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            .environment(\.layoutDirection, lang.layoutDirection)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showLanguagePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                            Text(lang.currentLanguage.displayName)
                                .font(.caption)
                        }
                    }
                }
            }
            .confirmationDialog(lang.tr("common.language"), isPresented: $showLanguagePicker, titleVisibility: .visible) {
                ForEach(HushTunnelLanguage.allCases) { l in
                    Button(l.displayName) {
                        lang.setLanguage(l)
                    }
                }
                Button(lang.tr("common.cancel"), role: .cancel) {}
            }
        }
    }

    private var isFormValid: Bool {
        return email.contains("@") && password.count >= 6
    }

    private func handleAuth() {
        guard isFormValid else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result: AuthResult
                if isLogin {
                    result = try await ApiClient.shared.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                } else {
                    result = try await ApiClient.shared.register(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                }

                await MainActor.run {
                    isLoading = false
                    authStore.saveSession(token: result.token, userId: result.userId, email: result.email, role: result.role)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
