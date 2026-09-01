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


public struct ServerNodeItem: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let countryCode: String
    public let flag: String
    public let city: String?
    public let host: String
    public let port: Int
    public let protocolName: String?
    public let isDefault: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, countryCode, flag, city, host, port
        case protocolName = "protocol"
        case isDefault
    }

    public init(id: String, name: String, countryCode: String, flag: String, city: String?, host: String, port: Int, protocolName: String?, isDefault: Bool?) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.flag = flag
        self.city = city
        self.host = host
        self.port = port
        self.protocolName = protocolName
        self.isDefault = isDefault
    }
}

public struct MeResult: Codable {
    public let email: String
    public let role: String
    public let subscriptions: [SubscriptionInfo]
    public let servers: [ServerNodeItem]?
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

public struct WalletTransactionItem: Codable, Identifiable, Hashable {
    public let id: String
    public let type: String
    public let amountUsd: Double
    public let balanceBefore: Double
    public let balanceAfter: Double
    public let description: String?
    public let counterpartEmail: String?
    public let createdAt: String
}

public struct WalletTransactionsResponse: Codable {
    public let success: Bool
    public let balanceUsd: Double
    public let transactions: [WalletTransactionItem]
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

public struct SubResellerCount: Codable, Hashable {
    public let customers: Int
    public let subscriptions: Int
}

public struct SubReseller: Codable, Identifiable, Hashable {
    public let id: String
    public let email: String
    public let balanceUsd: Double
    public let createdAt: String
    public let count: SubResellerCount?

    enum CodingKeys: String, CodingKey {
        case id, email, balanceUsd, createdAt
        case count = "_count"
    }

    public var customerCount: Int { count?.customers ?? 0 }
    public var subscriptionCount: Int { count?.subscriptions ?? 0 }
}

public struct SubResellersResponse: Codable {
    public let resellers: [SubReseller]
}

public struct CreateSubResellerResponse: Codable {
    public let reseller: CreatedSubReseller
}

public struct CreatedSubReseller: Codable {
    public let id: String
    public let email: String
    public let balanceUsd: Double
    public let generatedPassword: String
}

// MARK: - API Error

public struct ApiError: LocalizedError, Codable {
    public let error: String

    public var errorDescription: String? {
        return error
    }
}
