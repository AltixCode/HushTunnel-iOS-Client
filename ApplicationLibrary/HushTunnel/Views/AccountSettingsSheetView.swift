import Library
import SwiftUI

public struct AccountSettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var environments: ExtensionEnvironments
    @ObservedObject private var authStore = AuthStore.shared
    @ObservedObject private var lang = LanguageManager.shared
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showFinalConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section(lang.tr("privacy.title")) {
                    Label(lang.tr("privacy.noActivityLogs"), systemImage: "eye.slash.fill")
                    Text(lang.tr("privacy.minimumData"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button(lang.tr("privacy.policy")) {
                        if let url = URL(string: BrandConfig.privacyURL) { openURL(url) }
                    }
                    Button(lang.tr("terms.title")) {
                        if let url = URL(string: BrandConfig.termsURL) { openURL(url) }
                    }
                }
                Section {
                    Button(lang.tr("account.manageStoreSubscription")) {
                        Task { if let url = await RevenueCatManager.shared.managementURL() { openURL(url) } }
                    }
                } footer: {
                    Text(lang.tr("account.storeSubscriptionWarning"))
                }
                Section(lang.tr("account.deleteTitle")) {
                    Text(lang.tr("account.deleteDescription"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if authStore.role == "RESELLER" {
                        Text(lang.tr("account.deleteResellerWarning"))
                            .font(.footnote).foregroundColor(.orange)
                    }
                    SecureField(lang.tr("account.currentPassword"), text: $password)
                        .accessibilityIdentifier("hush.account.delete-password")
                    TextField(lang.tr("account.typeDelete"), text: $confirmation)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("hush.account.delete-confirmation")
                    if let errorMessage { Text(errorMessage).foregroundColor(.red).font(.footnote) }
                    Button(role: .destructive) { showFinalConfirmation = true } label: {
                        if isDeleting { ProgressView() } else { Text(lang.tr("account.deleteButton")) }
                    }
                    .disabled(password.isEmpty || confirmation != "DELETE" || isDeleting)
                    .accessibilityIdentifier("hush.account.delete-button")
                }
            }
            .navigationTitle(lang.tr("account.title"))
            .accessibilityIdentifier("hush.account.settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(lang.tr("common.close")) { dismiss() } } }
            .confirmationDialog(lang.tr("account.deleteConfirmTitle"), isPresented: $showFinalConfirmation, titleVisibility: .visible) {
                Button(lang.tr("account.deleteButton"), role: .destructive) { Task { await deleteAccount() } }
                Button(lang.tr("common.cancel"), role: .cancel) {}
            } message: { Text(lang.tr("account.deleteConfirmMessage")) }
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil
        do {
            try await ApiClient.shared.deleteAccount(password: password)
            try? await environments.extensionProfile?.stop()
            await RevenueCatManager.shared.logOutAndClear()
            authStore.logout()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }
}
