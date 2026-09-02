import Foundation

public struct SimpleSuccessResponse: Codable, Sendable {
    public let success: Bool?
}

public final class ApiClient: Sendable {
    public static let shared = ApiClient()

    private let session: URLSession


private final class RedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var redirectedRequest = request
        if let originalAuth = task.originalRequest?.value(forHTTPHeaderField: "Authorization") {
            redirectedRequest.setValue(originalAuth, forHTTPHeaderField: "Authorization")
        }
        completionHandler(redirectedRequest)
    }
}

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config, delegate: RedirectDelegate(), delegateQueue: nil)
    }

    private func makeRequest(
        path: String,
        method: String = "GET",
        token: String? = nil,
        body: [String: Any]? = nil,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(string: "\(BrandConfig.apiBaseURL)\(path)") else {
            throw URLError(.badURL)
        }
        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let tokenToUse = token ?? UserDefaults.standard.string(forKey: "com.hushtunnel.auth.token")
        if let tokenToUse = tokenToUse, !tokenToUse.isEmpty {
            request.setValue("Bearer \(tokenToUse)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        return request
    }

    /// Current app language as a `?locale=` query item, for endpoints that
    /// resolve locale-dependent fields (e.g. plan names) server-side.
    private func localeQueryItem() async -> URLQueryItem {
        let raw = await LanguageManager.shared.currentLanguage.rawValue
        return URLQueryItem(name: "locale", value: raw)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let apiError = try? JSONDecoder().decode(ApiError.self, from: data) {
                throw apiError
            }
            throw NSError(
                domain: "HushTunnelAPI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): Request failed"]
            )
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Auth

    public func login(email: String, password: String) async throws -> AuthResult {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let request = try makeRequest(
            path: "/api/mobile/login",
            method: "POST",
            body: ["email": cleanEmail, "password": password]
        )
        return try await perform(request)
    }

    public func register(email: String, password: String) async throws -> AuthResult {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let request = try makeRequest(
            path: "/api/mobile/register",
            method: "POST",
            body: ["email": cleanEmail, "password": password]
        )
        return try await perform(request)
    }

    public func me() async throws -> MeResult {
        let request = try makeRequest(path: "/api/mobile/me", queryItems: [await localeQueryItem()])
        return try await perform(request)
    }

    public func plans() async throws -> [PlanInfo] {
        let request = try makeRequest(path: "/api/mobile/plans", queryItems: [await localeQueryItem()])
        let res: PlansResponse = try await perform(request)
        return res.plans
    }

    public func gateways() async throws -> GatewayInfo {
        do {
            let request = try makeRequest(path: "/api/mobile/gateways")
            return try await perform(request)
        } catch {
            return GatewayInfo()
        }
    }

    public func checkout(planId: String, gateway: String, subscriptionId: String? = nil) async throws -> CheckoutResult {
        var body: [String: Any] = ["planId": planId, "gateway": gateway]
        if let subscriptionId = subscriptionId {
            body["subscriptionId"] = subscriptionId
        }
        let request = try makeRequest(path: "/api/mobile/checkout", method: "POST", body: body)
        return try await perform(request)
    }

    public func orderStatus(orderId: String) async throws -> OrderStatusResult {
        let request = try makeRequest(path: "/api/mobile/orders/\(orderId)")
        return try await perform(request)
    }

    public func orders() async throws -> [OrderItem] {
        let request = try makeRequest(path: "/api/mobile/orders", queryItems: [await localeQueryItem()])
        let res: OrdersResponse = try await perform(request)
        return res.orders
    }

    // MARK: - Reseller

    public func resellerOverview() async throws -> ResellerOverview {
        let request = try makeRequest(path: "/api/mobile/reseller/overview")
        return try await perform(request)
    }

    public func resellerCustomers() async throws -> [ResellerCustomer] {
        let request = try makeRequest(path: "/api/mobile/reseller/customers", queryItems: [await localeQueryItem()])
        let res: ResellerCustomersResponse = try await perform(request)
        return res.customers
    }

    public func createResellerCustomer(email: String, password: String? = nil) async throws -> CreateCustomerResponse {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var body: [String: Any] = ["email": cleanEmail]
        if let password = password, !password.isEmpty {
            body["password"] = password
        }
        let request = try makeRequest(path: "/api/mobile/reseller/customers", method: "POST", body: body)
        return try await perform(request)
    }

    public func resellerCustomerDetails(id: String) async throws -> ResellerCustomerDetail {
        let request = try makeRequest(path: "/api/mobile/reseller/customers/\(id)", queryItems: [await localeQueryItem()])
        let res: ResellerCustomerDetailResponse = try await perform(request)
        return res.customer
    }

    public func updateResellerCustomerPassword(id: String, newPassword: String? = nil) async throws -> ResetCustomerPasswordResponse {
        var body: [String: Any] = [:]
        if let newPassword = newPassword, !newPassword.isEmpty {
            body["newPassword"] = newPassword
        }
        let request = try makeRequest(path: "/api/mobile/reseller/customers/\(id)/password", method: "POST", body: body)
        return try await perform(request)
    }

    public func deleteResellerCustomer(id: String) async throws {
        let request = try makeRequest(path: "/api/mobile/reseller/customers/\(id)", method: "DELETE")
        let _: SimpleSuccessResponse = try await perform(request)
    }

    public func resellerOrders() async throws -> [ResellerOrder] {
        let request = try makeRequest(path: "/api/mobile/reseller/orders", queryItems: [await localeQueryItem()])
        let res: ResellerOrdersResponse = try await perform(request)
        return res.orders
    }

    public func createResellerOrder(customerEmail: String, planId: String, subscriptionId: String? = nil) async throws -> CreateResellerOrderResponse {
        var body: [String: Any] = ["customerEmail": customerEmail, "planId": planId]
        if let subscriptionId = subscriptionId {
            body["subscriptionId"] = subscriptionId
        }
        let request = try makeRequest(path: "/api/mobile/reseller/orders", method: "POST", body: body, queryItems: [await localeQueryItem()])
        return try await perform(request)
    }

    public func resellerSelfSubscription(planId: String, subscriptionId: String? = nil) async throws -> SelfSubscriptionResult {
        var body: [String: Any] = ["planId": planId]
        if let subscriptionId = subscriptionId {
            body["subscriptionId"] = subscriptionId
        }
        let request = try makeRequest(path: "/api/mobile/reseller/self-subscription", method: "POST", body: body)
        return try await perform(request)
    }

    public func resellerSubscriptions() async throws -> [ResellerSubscription] {
        let request = try makeRequest(path: "/api/mobile/reseller/subscriptions", queryItems: [await localeQueryItem()])
        let res: ResellerSubscriptionsResponse = try await perform(request)
        return res.subscriptions
    }

    public func extendResellerSubscription(id: String, days: Int) async throws {
        let request = try makeRequest(path: "/api/mobile/reseller/subscriptions/\(id)/extend", method: "POST", body: ["days": days])
        let _: SimpleSuccessResponse = try await perform(request)
    }

    public func toggleResellerSubscription(id: String, enable: Bool) async throws {
        let request = try makeRequest(path: "/api/mobile/reseller/subscriptions/\(id)/toggle", method: "POST", body: ["enable": enable])
        let _: SimpleSuccessResponse = try await perform(request)
    }

    public func resetResellerSubscriptionUuid(id: String) async throws {
        let request = try makeRequest(path: "/api/mobile/reseller/subscriptions/\(id)/reset-uuid", method: "POST")
        let _: SimpleSuccessResponse = try await perform(request)
    }

    public func resetResellerSubscriptionTraffic(id: String) async throws {
        let request = try makeRequest(path: "/api/mobile/reseller/subscriptions/\(id)/reset-traffic", method: "POST")
        let _: SimpleSuccessResponse = try await perform(request)
    }

    public func revokeResellerSubscription(id: String) async throws {
        let request = try makeRequest(path: "/api/mobile/reseller/subscriptions/\(id)/revoke", method: "POST")
        let _: SimpleSuccessResponse = try await perform(request)
    }

    public func walletTransactions() async throws -> [WalletTransactionItem] {
        let request = try makeRequest(path: "/api/mobile/wallet/transactions", queryItems: [await localeQueryItem()])
        let res: WalletTransactionsResponse = try await perform(request)
        return res.transactions
    }

    public func transferFunds(recipientEmail: String, amountUsd: Double, description: String? = nil) async throws -> TransferFundsResponse {
        var body: [String: Any] = [
            "recipientEmail": recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "amountUsd": amountUsd,
        ]
        if let description = description, !description.isEmpty {
            body["description"] = description
        }
        let request = try makeRequest(path: "/api/mobile/wallet/transfer", method: "POST", body: body)
        return try await perform(request)
    }

    public func resellerDeposits() async throws -> [ResellerDeposit] {
        let request = try makeRequest(path: "/api/mobile/reseller/deposits")
        let res: ResellerDepositsResponse = try await perform(request)
        return res.deposits
    }

    public func createResellerDeposit(amountUsd: Double, gateway: String) async throws -> CreateDepositResponse {
        let request = try makeRequest(
            path: "/api/mobile/reseller/deposits",
            method: "POST",
            body: ["amountUsd": amountUsd, "gateway": gateway]
        )
        return try await perform(request)
    }

    public func resellerSubResellers() async throws -> [SubReseller] {
        let request = try makeRequest(path: "/api/mobile/reseller/resellers")
        let res: SubResellersResponse = try await perform(request)
        return res.resellers
    }

    public func createSubReseller(email: String, initialBalanceUsd: Double) async throws -> CreatedSubReseller {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let request = try makeRequest(
            path: "/api/mobile/reseller/resellers",
            method: "POST",
            body: ["email": cleanEmail, "initialBalanceUsd": initialBalanceUsd]
        )
        let res: CreateSubResellerResponse = try await perform(request)
        return res.reseller
    }

    public func changePassword(currentPassword: String?, newPassword: String) async throws {
        var body: [String: Any] = ["newPassword": newPassword]
        if let current = currentPassword, !current.isEmpty {
            body["currentPassword"] = current
        }
        let request = try makeRequest(path: "/api/mobile/account/password", method: "POST", body: body)
        let _: SimpleSuccessResponse = try await perform(request)
    }
}
