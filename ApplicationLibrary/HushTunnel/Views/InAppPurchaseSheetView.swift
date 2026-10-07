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

                // Guideline 3.1.2 requires an auto-renewable subscription to be
                // sold alongside FUNCTIONAL links to the Terms of Use (EULA)
                // and the Privacy Policy, on the screen where it is sold. The
                // title, the length and the price were all here; these two were
                // not, and their absence is one of the most commonly cited
                // reasons for a 3.1.2 rejection.
                //
                // Both pages exist and answer 200, and both constants are
                // already used by AuthView and AccountSettingsSheetView -- the
                // links were simply never surfaced on the purchase screen,
                // which is the one screen the guideline is about.
                Section {
                    if let terms = URL(string: BrandConfig.termsURL) {
                        Link(lang.tr("terms.title"), destination: terms)
                            .accessibilityIdentifier("hush.iap.terms")
                    }
                    if let privacy = URL(string: BrandConfig.privacyURL) {
                        Link(lang.tr("privacy.policy"), destination: privacy)
                            .accessibilityIdentifier("hush.iap.privacy")
                    }
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
        // A section with nothing to buy is not rendered at all.
        //
        // The wallet consumables are offered by RevenueCat but were never
        // created in App Store Connect, so StoreKit returns no product for them
        // and this section rendered its header over the words "In-app purchases
        // are not available yet." That sentence was accurate and still wrong to
        // show: the app was advertising a purchase path that does not exist,
        // and it appeared directly beneath four subscriptions that load fine.
        // Apple had just rejected this app under 3.1.1 for being unable to find
        // its in-app purchases, which is the reading that line invites.
        //
        // An *error* still surfaces -- if prepare() actually failed, every
        // section is empty for a reason the user needs to see. Only the silent
        // "this product does not exist" case is dropped, and `isLoading` keeps
        // the placeholder from flashing before the catalogue arrives.
        if !items.isEmpty || purchases.errorMessage != nil, !purchases.isLoading {
            Section(title) {
                if items.isEmpty, let errorMessage = purchases.errorMessage {
                    Text(errorMessage).foregroundColor(.secondary)
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
