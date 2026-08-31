import Foundation

// MARK: - Consumer Models

public struct PlanInfo: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String?
    public let priceUsd: Double
    public let durationDays: Int
    public let trafficLimitGb: Int
}

public struct PlansResponse: Codable {
    public let plans: [PlanInfo]
}

public struct SubscriptionInfo: Codable, Identifiable, Hashable {
    public let id: String
    public let planName: String
    public let expiryDate: String
    public let isActive: Bool
    public let usedBytes: Int64
    public let totalBytes: Int64
    public let subscriptionUrl: String
}

public struct MeResult: Codable {
    public let email: String
    public let role: String
    public let subscriptions: [SubscriptionInfo]
}

public struct AuthResult: Codable {
    public let token: String
    public let email: String
    public let role: String
}

public struct GatewayInfo: Codable {
    public let cryptomus: Bool
    public let nowpayments: Bool
    public let revolut: Bool

    public init(cryptomus: Bool = false, nowpayments: Bool = false, revolut: Bool = false) {
        self.cryptomus = cryptomus
        self.nowpayments = nowpayments
        self.revolut = revolut
    }
}

public struct CheckoutResult: Codable {
    public let orderId: String
    public let checkoutUrl: String?
    public let gateway: String
}

public struct OrderStatusResult: Codable {
    public let id: String
    public let status: String
    public let subscriptionId: String?
}

public struct OrderItem: Codable, Identifiable, Hashable {
    public let id: String
    public let planName: String
    public let amountUsd: Double
    public let gateway: String
    public let status: String
    public let createdAt: String
    public let subscriptionId: String?
}

public struct OrdersResponse: Codable {
    public let orders: [OrderItem]
}

// MARK: - Reseller Models

public struct NextTierInfo: Codable, Hashable {
    public let minBalance: Double
    public let discountPct: Int
}

public struct ResellerOverview: Codable {
    public let balanceUsd: Double
    public let discountPct: Int
    public let nextTier: NextTierInfo?
    public let totalCustomers: Int?
    public let totalSubscriptions: Int?
}

public struct ResellerCustomerSubInfo: Codable, Identifiable, Hashable {
    public let id: String
    public let planName: String
    public let expiryDate: String
    public let isActive: Bool
}

public struct ResellerCustomer: Codable, Identifiable, Hashable {
    public let id: String
    public let email: String
    public let createdAt: String
    public let activeSubscriptionsCount: Int?
    public let subscriptions: [ResellerCustomerSubInfo]?
}

public struct ResellerCustomersResponse: Codable {
    public let customers: [ResellerCustomer]
}

public struct CreateCustomerResponse: Codable {
    public let id: String
    public let email: String
    public let generatedPassword: String
    public let createdAt: String
}

public struct ResetCustomerPasswordResponse: Codable {
    public let success: Bool
    public let newPassword: String
}

public struct ResellerCustomerDetail: Codable {
    public let id: String
    public let email: String
    public let createdAt: String
    public let subscriptions: [SubscriptionInfo]
    public let orders: [OrderItem]
}

public struct ResellerCustomerDetailResponse: Codable {
    public let customer: ResellerCustomerDetail
}

public struct ResellerOrder: Codable, Identifiable, Hashable {
    public let id: String
    public let customerEmail: String
    public let planName: String
    public let amountUsd: Double
    public let status: String
    public let createdAt: String
    public let subscriptionId: String?
    public let paidFromBalance: Bool?
}

public struct ResellerOrdersResponse: Codable {
    public let orders: [ResellerOrder]
}

public struct CreateResellerOrderResponse: Codable {
    public let orderId: String
    public let customerEmail: String?
    public let generatedPassword: String?
    public let amountUsd: Double?
}

public struct SelfSubscriptionResult: Codable {
    public let success: Bool
    public let orderId: String
    public let subscriptionId: String?
    public let amountUsd: Double
}

public struct ResellerSubscription: Codable, Identifiable, Hashable {
    public let id: String
    public let customerEmail: String
    public let planName: String
    public let expiryDate: String
    public let isActive: Bool
    public let usedBytes: Int64
    public let totalBytes: Int64
    public let isSelf: Bool?
}

public struct ResellerSubscriptionsResponse: Codable {
    public let subscriptions: [ResellerSubscription]
}

public struct ResellerDeposit: Codable, Identifiable, Hashable {
    public let id: String
    public let amountUsd: Double
    public let gateway: String
    public let status: String
    public let createdAt: String
    public let checkoutUrl: String?
}

public struct ResellerDepositsResponse: Codable {
    public let deposits: [ResellerDeposit]
}

public struct CreateDepositResponse: Codable {
    public let depositId: String
    public let amountUsd: Double
    public let gateway: String
    public let status: String
    public let checkoutUrl: String?
}

// MARK: - API Error

public struct ApiError: LocalizedError, Codable {
    public let error: String

    public var errorDescription: String? {
        return error
    }
}
