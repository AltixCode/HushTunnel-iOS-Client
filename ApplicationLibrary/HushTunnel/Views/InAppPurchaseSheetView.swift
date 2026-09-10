import SwiftUI

public struct InAppPurchaseSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchases = RevenueCatManager.shared
    @ObservedObject private var lang = LanguageManager.shared
    @State private var purchasingId: String?
    @State private var message: String?
    let onPurchaseCompleted: () -> Void

    public init(onPurchaseCompleted: @escaping () -> Void) {
        self.onPurchaseCompleted = onPurchaseCompleted
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(lang.tr("iap.description"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                productSection(.subscription, title: lang.tr("iap.subscriptions"))
                productSection(.wallet, title: lang.tr("iap.addFunds"))
                Section {
                    Button(lang.tr("iap.restore")) {
                        Task { await restore() }
                    }
                    .accessibilityIdentifier("hush.iap.restore")
                } footer: {
                    Text(lang.tr("iap.storeBillingNote"))
                }
                if let message {
                    Section { Text(message).foregroundColor(.secondary) }
                }
            }
            .overlay {
                if purchases.isLoading { ProgressView() }
            }
            .navigationTitle(lang.tr("iap.title"))
            .accessibilityIdentifier("hush.iap.sheet")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(lang.tr("common.close")) { dismiss() } } }
            .task { await purchases.prepare() }
        }
    }

    @ViewBuilder
    private func productSection(_ kind: IAPProductKind, title: String) -> some View {
        let items = purchases.products.filter { $0.kind == kind }
        Section(title) {
            if items.isEmpty && !purchases.isLoading {
                Text(purchases.errorMessage ?? lang.tr("iap.unavailable")).foregroundColor(.secondary)
            }
            ForEach(items) { product in
                Button {
                    Task { await purchase(product) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(product.title).foregroundColor(.primary)
                            Text(product.detail).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if purchasingId == product.id { ProgressView() } else { Text(product.price).fontWeight(.semibold) }
                    }
                }
                .disabled(purchasingId != nil)
                .accessibilityIdentifier("hush.iap.product.\(product.kind.rawValue)")
            }
        }
    }

    private func purchase(_ product: IAPDisplayProduct) async {
        purchasingId = product.id
        defer { purchasingId = nil }
        do {
            try await purchases.purchase(productId: product.id)
            message = lang.tr("iap.purchaseProcessing")
            try? await Task.sleep(for: .seconds(2))
            onPurchaseCompleted()
        } catch {
            let nsError = error as NSError
            if nsError.domain != "RevenueCat.ErrorCode" || nsError.code != 1 { message = error.localizedDescription }
        }
    }

    private func restore() async {
        do {
            try await purchases.restorePurchases()
            message = lang.tr("iap.restoreComplete")
            onPurchaseCompleted()
        } catch { message = error.localizedDescription }
    }
}
