import SwiftUI

public struct ChangePasswordSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var lang = LanguageManager.shared

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(lang.tr("account.changePassword"))) {
                    SecureField(lang.tr("account.currentPassword"), text: $currentPassword)
                        .textContentType(.password)

                    SecureField(lang.tr("account.newPassword"), text: $newPassword)
                        .textContentType(.newPassword)

                    SecureField(lang.tr("auth.password"), text: $confirmPassword)
                        .textContentType(.newPassword)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }

                if let success = successMessage {
                    Section {
                        Text(success)
                            .font(.footnote)
                            .foregroundColor(.green)
                    }
                }

                Section {
                    Button(action: submitPasswordChange) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text(lang.tr("account.changePassword"))
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || newPassword.count < 6)
                }
            }
            .environment(\.layoutDirection, lang.layoutDirection)
            .navigationTitle(lang.tr("account.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(lang.tr("common.cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func submitPasswordChange() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await ApiClient.shared.changePassword(
                    currentPassword: currentPassword.isEmpty ? nil : currentPassword,
                    newPassword: newPassword
                )
                await MainActor.run {
                    isLoading = false
                    successMessage = lang.tr("account.passwordSuccess")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        presentationMode.wrappedValue.dismiss()
                    }
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
