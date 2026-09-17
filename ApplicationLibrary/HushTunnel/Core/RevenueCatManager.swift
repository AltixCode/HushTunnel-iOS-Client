import Foundation
import RevenueCat

public enum IAPProductKind: String, Sendable {
    case subscription
    case wallet
}

public struct IAPDisplayProduct: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let price: String
    public let kind: IAPProductKind
}

@MainActor
public final class RevenueCatManager: ObservableObject {
    public static let shared = RevenueCatManager()

    @Published public private(set) var products: [IAPDisplayProduct] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isConfigured = false
    @Published public private(set) var errorMessage: String?

    private var packages: [String: Package] = [:]
    private var currentAppUserId: String?

    private init() {}

    public func prepare() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let config = try await ApiClient.shared.iapConfig()
            guard config.enabled, let key = config.publicSdkKey, !key.isEmpty else {
                throw NSError(domain: "HushTunnelIAP", code: 1, userInfo: [NSLocalizedDescriptionKey: LanguageManager.shared.tr("iap.unavailable")])
            }

            if !isConfigured {
                Purchases.logLevel = _isDebugAssertConfiguration() ? .debug : .warn
                Purchases.configure(withAPIKey: key, appUserID: config.appUserId)
                isConfigured = true
                currentAppUserId = config.appUserId
            } else if currentAppUserId != config.appUserId {
                _ = try await Purchases.shared.logIn(config.appUserId)
                currentAppUserId = config.appUserId
            }

            let offerings = try await Purchases.shared.offerings()
            let available = offerings.current?.availablePackages ?? []
            packages = Dictionary(uniqueKeysWithValues: available.map { ($0.storeProduct.productIdentifier, $0) })
            let subscriptions = Dictionary(uniqueKeysWithValues: config.subscriptionProducts.map { ($0.productId, $0) })
            let wallet = Dictionary(uniqueKeysWithValues: config.walletProducts.map { ($0.productId, $0) })

            // RevenueCat returns `availablePackages` in the offering's own order,
            // which is not the order a price ladder has to be read in: the live
            // App Store screenshot shows 1 Month, 3 Months, 12 Months, 6 Months,
            // and nobody can see that six months is better value per day than
            // three when twelve is sitting between them.
            //
            // So sort explicitly. Subscriptions come first, shortest term first;
            // wallet credit follows, smallest first. Sorting on the plan's own
            // `durationDays` rather than on the price string is deliberate --
            // `localizedPriceString` is text in the user's currency, and sorting
            // storefront text produces a different order per region.
            let ranked: [(rank: (Int, Int), product: IAPDisplayProduct)] = available.compactMap { package in
                let id = package.storeProduct.productIdentifier.split(separator: ":", maxSplits: 1).first.map(String.init) ?? package.storeProduct.productIdentifier
                if let product = subscriptions[id] {
                    return (
                        (0, product.durationDays),
                        IAPDisplayProduct(
                            id: package.storeProduct.productIdentifier,
                            title: package.storeProduct.localizedTitle,
                            detail: String(format: LanguageManager.shared.tr("iap.subscriptionDays"), product.durationDays),
                            price: package.storeProduct.localizedPriceString,
                            kind: .subscription
                        )
                    )
                }
                if let product = wallet[id] {
                    return (
                        (1, Int(product.creditUsd.rounded())),
                        IAPDisplayProduct(
                            id: package.storeProduct.productIdentifier,
                            title: package.storeProduct.localizedTitle,
                            detail: String(format: LanguageManager.shared.tr("iap.walletCredit"), product.creditUsd),
                            price: package.storeProduct.localizedPriceString,
                            kind: .wallet
                        )
                    )
                }
                return nil
            }
            products = ranked
                .sorted { $0.rank < $1.rank }
                .map(\.product)
        } catch {
            products = []
            packages = [:]
            errorMessage = error.localizedDescription
        }
    }

    public func purchase(productId: String) async throws {
        guard let package = packages[productId] else {
            throw NSError(domain: "HushTunnelIAP", code: 2, userInfo: [NSLocalizedDescriptionKey: LanguageManager.shared.tr("iap.unavailable")])
        }
        _ = try await Purchases.shared.purchase(package: package)
    }

    public func restorePurchases() async throws {
        guard isConfigured else { return }
        _ = try await Purchases.shared.restorePurchases()
    }

    public func managementURL() async -> URL? {
        guard isConfigured else { return URL(string: "https://apps.apple.com/account/subscriptions") }
        return (try? await Purchases.shared.customerInfo().managementURL)
            ?? URL(string: "https://apps.apple.com/account/subscriptions")
    }

    public func logOutAndClear() async {
        if isConfigured { _ = try? await Purchases.shared.logOut() }
        clearCachedProducts()
    }

    /// For ordinary app logout, retain RevenueCat's identified customer until
    /// the next HushTunnel login calls `logIn` with the new database user ID.
    /// This avoids creating an anonymous RevenueCat customer between sessions.
    public func clearCachedProducts() {
        packages = [:]
        products = []
    }
}
