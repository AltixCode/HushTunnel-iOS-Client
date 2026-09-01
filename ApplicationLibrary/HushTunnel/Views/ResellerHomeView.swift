
private extension CGColor {
    static var labelColor: CGColor {
        #if canImport(UIKit)
            UIColor.label.cgColor
        #elseif canImport(AppKit)
            NSColor.labelColor.cgColor
        #endif
    }
}

import Library
import SwiftUI

public struct ResellerHomeView: View {
    @ObservedObject var authStore = AuthStore.shared
    @ObservedObject var lang = LanguageManager.shared
    @EnvironmentObject private var environments: ExtensionEnvironments

    @State private var selectedTab = 0
    @State private var overview: ResellerOverview?
    @State private var customers: [ResellerCustomer] = []
    @State private var subscriptions: [ResellerSubscription] = []
    // The reseller's own personal subscription, fetched the same way a plain
    // USER account's is (/api/mobile/me) — ResellerSubscription (from
    // /api/mobile/reseller/subscriptions) covers only *customers'*
    // subscriptions and has no subscriptionUrl to provision a VPN connection
    // from. Mirrors the Android fork's ResellerHomeViewModel.refresh().
    @State private var personalSubscriptions: [SubscriptionInfo] = []
    @State private var orders: [ResellerOrder] = []
    @State private var deposits: [ResellerDeposit] = []
    @State private var transactions: [WalletTransactionItem] = []
    @State private var subResellers: [SubReseller] = []
    @State private var plans: [PlanInfo] = []
    @State private var gateways = GatewayInfo()
    @State private var servers: [ServerNodeItem] = []
    @State private var selectedServer: ServerNodeItem? = nil
    @State private var showServerPickerSheet = false

    @State private var isLoading = false
    @State private var provisionError: String?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    // Dialog sheets
    @State private var showChangePasswordSheet = false
    @State private var showSelfSubSheet = false
    @State private var showAddCustomerSheet = false
    @State private var showCreateOrderSheet = false
    @State private var showDepositSheet = false
    @State private var showAddSubResellerSheet = false
    @State private var showLanguagePicker = false
    @State private var selectedCustomerForDetail: ResellerCustomer?
    @State private var showCustomerDetailSheet = false
    @State private var prefilledOrderEmail = ""
    @State private var activeConnectionDetails: ResellerConnectionDetails?

    public init() {}

    public var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Tab 0: Personal VPN
                ResellerPersonalVpnTabView(
                    overview: overview,
                    personalSub: personalSubscriptions.first(where: { $0.isActive }),
                    extensionProfile: environments.extensionProfile,
                    provisionError: provisionError,
                    servers: servers,
                    selectedServer: selectedServer,
                    onOpenServerPicker: { showServerPickerSheet = true },
                    onCreateSelfSub: { showSelfSubSheet = true }
                )
                .tabItem {
                    Label(lang.tr("reseller.tab.vpn"), systemImage: "shield.fill")
                }
                .tag(0)

                // Tab 1: Dashboard & Wallet
                ResellerDashboardTabView(
                    overview: overview,
                    onAddFunds: { showDepositSheet = true },
                    onNewCustomer: { showAddCustomerSheet = true },
                    onNewReseller: { showAddSubResellerSheet = true },
                    onNewOrder: { showCreateOrderSheet = true }
                )
                .tabItem {
                    Label(lang.tr("reseller.tab.overview"), systemImage: "chart.pie.fill")
                }
                .tag(1)

                // Tab 2: Customers CRUD
                ResellerCustomersTabView(
                    customers: customers,
                    onAddCustomer: { showAddCustomerSheet = true },
                    onSelectCustomer: { c in
                        selectedCustomerForDetail = c
                        showCustomerDetailSheet = true
                    },
                    onRefresh: refreshAll
                )
                .tabItem {
                    Label(lang.tr("reseller.tab.customers"), systemImage: "person.2.fill")
                }
                .tag(2)

                // Tab 3: Subscriptions
                ResellerSubscriptionsTabView(
                    subscriptions: subscriptions,
                    onExtend: { subId in extendSub(id: subId) },
                    onToggle: { subId, enable in toggleSub(id: subId, enable: enable) },
                    onResetUuid: { subId in resetUuid(id: subId) },
                    onResetTraffic: { subId in resetTraffic(id: subId) },
                    onRevoke: { subId in revokeSub(id: subId) },
                    onSelectSub: { sub in
                        activeConnectionDetails = ResellerConnectionDetails(
                            title: sub.customerEmail,
                            planName: sub.planName,
                            subscriptionUrl: sub.subscriptionUrl,
                            vlessLink: sub.vlessLink,
                            expiryDate: sub.expiryDate,
                            status: sub.isActive ? "ACTIVE" : "INACTIVE"
                        )
                    }
                )
                .tabItem {
                    Label(lang.tr("reseller.tab.subscriptions"), systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(3)

                // Tab 4: Orders & Transactions
                ResellerOrdersAndTransactionsTabView(
                    orders: orders,
                    transactions: transactions,
                    onSelectOrder: { order in
                        activeConnectionDetails = ResellerConnectionDetails(
                            title: order.customerEmail,
                            planName: order.planName,
                            subscriptionUrl: order.subscriptionUrl,
                            vlessLink: order.vlessLink,
                            amountUsd: order.amountUsd,
                            status: order.status
                        )
                    }
                )
                .tabItem {
                    Label(lang.tr("reseller.tab.orders"), systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(4)

                // Tab 5: Sub-Resellers
                ResellerSubResellersTabView(
                    subResellers: subResellers,
                    onAddSubReseller: { showAddSubResellerSheet = true }
                )
                .tabItem {
                    Label(lang.tr("reseller.tab.subresellers"), systemImage: "person.3.fill")
                }
                .tag(5)
            }
            .environment(\.layoutDirection, lang.layoutDirection)
            .navigationTitle(BrandConfig.appName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showLanguagePicker = true
                    } label: {
                        Image(systemName: "globe")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showChangePasswordSheet = true
                        } label: {
                            Image(systemName: "lock.rotation")
                        }

                        Button(action: refreshAll) {
                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }

                        Button {
                            authStore.logout()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
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
            .sheet(isPresented: $showChangePasswordSheet) {
                ChangePasswordSheetView()
            }
            .sheet(isPresented: $showServerPickerSheet) {
                ServerPickerSheetView(
                    servers: servers,
                    selectedServer: selectedServer,
                    onSelect: { s in
                        selectedServer = s
                        Task {
                            if let activeSub = personalSubscriptions.first(where: { $0.isActive }) {
                                do {
                                    try await ProvisionHelper.provisionSubscription(subscriptionUrl: activeSub.subscriptionUrl, preferredServerId: s.id)
                                    if environments.extensionProfile?.status == .connected {
                                        try await environments.extensionProfile?.restart()
                                    }
                                } catch {
                                    print("Error switching server: \(error)")
                                }
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showSelfSubSheet) {
                ResellerSelfSubSheetView(plans: plans, balance: overview?.balanceUsd ?? 0, onCompleted: refreshAll)
            }
            .sheet(isPresented: $showAddCustomerSheet) {
                ResellerAddCustomerSheetView(
                    onCompleted: refreshAll,
                    onCustomerCreated: { createdEmail in
                        prefilledOrderEmail = createdEmail
                        showCreateOrderSheet = true
                    }
                )
            }
            .sheet(isPresented: $showCreateOrderSheet) {
                ResellerCreateOrderSheetView(
                    plans: plans,
                    customers: customers,
                    initialEmail: prefilledOrderEmail,
                    balance: overview?.balanceUsd ?? 0,
                    onCompleted: {
                        prefilledOrderEmail = ""
                        refreshAll()
                    },
                    onOrderSuccess: { res in
                        let email = res.customerEmail ?? prefilledOrderEmail
                        prefilledOrderEmail = ""
                        activeConnectionDetails = ResellerConnectionDetails(
                            title: email,
                            planName: res.planName ?? "Active Plan",
                            subscriptionUrl: res.subscriptionUrl,
                            vlessLink: res.vlessLink,
                            generatedPassword: res.generatedPassword,
                            amountUsd: res.amountUsd
                        )
                    }
                )
            }
            .sheet(item: $activeConnectionDetails) { details in
                ResellerConnectionQrSheetView(details: details)
            }
            .sheet(isPresented: $showDepositSheet) {
                ResellerDepositSheetView(gateways: gateways, onCompleted: refreshAll)
            }
            .sheet(isPresented: $showAddSubResellerSheet) {
                ResellerAddSubResellerSheetView(balance: overview?.balanceUsd ?? 0, onCompleted: refreshAll)
            }
            .sheet(isPresented: $showCustomerDetailSheet) {
                if let c = selectedCustomerForDetail {
                    ResellerCustomerDetailSheetView(customer: c, onDeleted: {
                        showCustomerDetailSheet = false
                        refreshAll()
                    })
                }
            }
            .task {
                await environments.reload()
            }
            .onAppear(perform: refreshAll)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refreshAll()
            }
        }
    }

    private func refreshAll() {
        isLoading = true
        Task {
            do {
                async let ovTask = ApiClient.shared.resellerOverview()
                async let custTask = ApiClient.shared.resellerCustomers()
                async let subTask = ApiClient.shared.resellerSubscriptions()
                async let meTask = ApiClient.shared.me()
                async let ordTask = ApiClient.shared.resellerOrders()
                async let depTask = ApiClient.shared.resellerDeposits()
                async let plTask = ApiClient.shared.plans()
                async let gwTask = ApiClient.shared.gateways()
                async let subResTask = ApiClient.shared.resellerSubResellers()

                let (ov, cust, sub, me, ord, dep, pl, gw, subRes) = try await (ovTask, custTask, subTask, meTask, ordTask, depTask, plTask, gwTask, subResTask)

                await MainActor.run {
                    self.overview = ov
                    self.customers = cust
                    self.subscriptions = sub
                    self.personalSubscriptions = me.subscriptions
                    self.orders = ord
                    self.deposits = dep
                    self.plans = pl
                    self.gateways = gw
                    self.subResellers = subRes
                    self.isLoading = false
                }

                if let activeSub = me.subscriptions.first(where: { $0.isActive }) {
                    do {
                        try await ProvisionHelper.provisionSubscription(subscriptionUrl: activeSub.subscriptionUrl)
                        await MainActor.run { self.provisionError = nil }
                    } catch {
                        await MainActor.run {
                            self.provisionError = "Couldn't set up your VPN connection: \(error.localizedDescription)"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func extendSub(id: String) {
        Task {
            try? await ApiClient.shared.extendResellerSubscription(id: id, days: 30)
            refreshAll()
        }
    }

    private func toggleSub(id: String, enable: Bool) {
        Task {
            try? await ApiClient.shared.toggleResellerSubscription(id: id, enable: enable)
            refreshAll()
        }
    }

    private func resetUuid(id: String) {
        Task {
            try? await ApiClient.shared.resetResellerSubscriptionUuid(id: id)
            refreshAll()
        }
    }

    private func resetTraffic(id: String) {
        Task {
            try? await ApiClient.shared.resetResellerSubscriptionTraffic(id: id)
            refreshAll()
        }
    }

    private func revokeSub(id: String) {
        Task {
            try? await ApiClient.shared.revokeResellerSubscription(id: id)
            refreshAll()
        }
    }
}

// MARK: - Tab 0: Personal VPN Tab

public struct ResellerPersonalVpnTabView: View {
    let overview: ResellerOverview?
    let personalSub: SubscriptionInfo?
    let extensionProfile: ExtensionProfile?
    let provisionError: String?
    let servers: [ServerNodeItem]
    let selectedServer: ServerNodeItem?
    let onOpenServerPicker: () -> Void
    let onCreateSelfSub: () -> Void
    @ObservedObject var lang = LanguageManager.shared

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Connect Circle — wired to the real ExtensionProfile the same
                // way UserHomeView is; a reseller is also a customer of their
                // own service and gets the same working connect/disconnect.
                if let profile = extensionProfile {
                    ConnectCircleButton(profile: profile)
                        .padding(.top, 24)
                    ConnectStatusLabel(profile: profile)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 140, height: 140)
                        ProgressView()
                    }
                    .padding(.top, 24)
                }

                if let provisionError {
                    Text(provisionError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Server Location Selector Card
                Button(action: onOpenServerPicker) {
                    HStack(spacing: 14) {
                        let currentServer = selectedServer ?? servers.first(where: { $0.isDefault == true }) ?? servers.first
                        Text(currentServer?.flag ?? "🇳🇱")
                            .font(.system(size: 30))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(currentServer?.name ?? "Netherlands 01 (Amsterdam)")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("\(currentServer?.city ?? currentServer?.countryCode ?? "Amsterdam") · VLESS-Reality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("Switch")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(8)
                    }
                    .padding(16)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(PlainButtonStyle())

                // Personal VPN Status Card
                if let sub = personalSub {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("My Personal Connection")
                                .font(.headline)
                            Spacer()
                            Text(sub.isActive ? "Active" : "Disabled")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(sub.isActive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .foregroundColor(sub.isActive ? .green : .red)
                                .cornerRadius(6)
                        }

                        Text("Plan: \(sub.planName) · Expires: \(sub.expiryDate.prefix(10))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if sub.totalBytes > 0 {
                            let pct = min(1.0, Double(sub.usedBytes) / Double(sub.totalBytes))
                            ProgressView(value: pct).tint(.accentColor)
                        }
                    }
                    .padding(20)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal, 16)
                } else {
                    // No personal connection created yet
                    VStack(spacing: 12) {
                        Image(systemName: "shield.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("No Personal VPN Configured")
                            .font(.headline)
                        Text("You can provision a personal connection for yourself instantly using your prepaid balance.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        Button(action: onCreateSelfSub) {
                            Text(lang.tr("reseller.createMyVpn"))
                                .fontWeight(.semibold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.top, 6)
                    }
                    .padding(24)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Tab 1: Dashboard Tab

public struct ResellerDashboardTabView: View {
    let overview: ResellerOverview?
    let onAddFunds: () -> Void
    let onNewCustomer: () -> Void
    let onNewReseller: () -> Void
    let onNewOrder: () -> Void
    @ObservedObject var lang = LanguageManager.shared

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Wallet Balance Card
                VStack(alignment: .leading, spacing: 14) {
                    Text(lang.tr("reseller.balance"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("$\(String(format: "%.2f", overview?.balanceUsd ?? 0))")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.accentColor)

                    HStack {
                        Text("\(lang.tr("reseller.discount")): \(overview?.discountPct ?? 0)%")
                            .font(.footnote)
                            .fontWeight(.semibold)

                        Spacer()

                        if let next = overview?.nextTier {
                            Text("Next tier: \(next.discountPct)% at $\(Int(next.minBalance))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://www.hushtunnel.com")!) {
                        HStack {
                            Image(systemName: "arrow.up.forward.app.fill")
                            Text("Top Up at hushtunnel.com")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(20)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(20)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Quick Action Buttons
                VStack(spacing: 12) {
                    Button(action: onNewOrder) {
                        HStack {
                            Image(systemName: "cart.badge.plus")
                            Text(lang.tr("reseller.newOrder"))
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(14)
                    }

                    Button(action: onNewCustomer) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text(lang.tr("reseller.addCustomer"))
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(14)
                    }

                    Button(action: onNewReseller) {
                        HStack {
                            Image(systemName: "person.2.badge.plus")
                            Text(lang.tr("reseller.addSubReseller"))
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Tab 2: Customers Tab

public struct ResellerCustomersTabView: View {
    let customers: [ResellerCustomer]
    let onAddCustomer: () -> Void
    let onSelectCustomer: (ResellerCustomer) -> Void
    let onRefresh: () -> Void
    @State private var search = ""
    @ObservedObject var lang = LanguageManager.shared

    private var filtered: [ResellerCustomer] {
        if search.isEmpty { return customers }
        return customers.filter { $0.email.localizedCaseInsensitiveContains(search) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search customer email...", text: $search)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(10)

                Button(action: onAddCustomer) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(16)

            List(filtered) { customer in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.email)
                            .fontWeight(.medium)
                        Text("Created: \(customer.createdAt.prefix(10))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectCustomer(customer)
                }
            }
        }
    }
}

// MARK: - Tab 3: Subscriptions Tab

public struct ResellerSubscriptionsTabView: View {
    let subscriptions: [ResellerSubscription]
    let onExtend: (String) -> Void
    let onToggle: (String, Bool) -> Void
    let onResetUuid: (String) -> Void
    let onResetTraffic: (String) -> Void
    let onRevoke: (String) -> Void
    var onSelectSub: ((ResellerSubscription) -> Void)? = nil

    public var body: some View {
        List(subscriptions) { sub in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sub.customerEmail)
                            .fontWeight(.semibold)
                        Text("\(sub.planName) · Expires \(sub.expiryDate.prefix(10))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(sub.isActive ? "Active" : "Disabled")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(sub.isActive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .foregroundColor(sub.isActive ? .green : .red)
                        .cornerRadius(6)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectSub?(sub)
                }

                // Action Row
                HStack(spacing: 8) {
                    Button("+30 Days") { onExtend(sub.id) }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(6)

                    Button(sub.isActive ? "Disable" : "Enable") { onToggle(sub.id, !sub.isActive) }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(6)

                    Button("Reset UUID") { onResetUuid(sub.id) }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(6)

                    Spacer()

                    Button("Revoke") { onRevoke(sub.id) }
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Tab 4: Orders and Deposits Tab

public struct ResellerOrdersAndTransactionsTabView: View {
    let orders: [ResellerOrder]
    let transactions: [WalletTransactionItem]
    var onSelectOrder: ((ResellerOrder) -> Void)? = nil
    @State private var section = 0
    @State private var searchText = ""

    var filteredTransactions: [WalletTransactionItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return transactions
        }
        let q = searchText.lowercased()
        return transactions.filter {
            ($0.description ?? "").lowercased().contains(q) ||
            $0.type.lowercased().contains(q) ||
            ($0.counterpartEmail ?? "").lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $section) {
                Text("Orders (\(orders.count))").tag(0)
                Text("Transactions (\(transactions.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(16)

            if section == 0 {
                if orders.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "cart")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No orders placed yet.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(orders) { order in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.customerEmail)
                                    .fontWeight(.medium)
                                Text("\(order.planName) · \(order.createdAt.prefix(10))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("$\(String(format: "%.2f", order.amountUsd))")
                                    .fontWeight(.bold)
                                Text(order.status)
                                    .font(.caption2)
                                    .foregroundColor(order.status == "PAID" ? .green : .orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectOrder?(order)
                        }
                    }
                }
            } else {
                if transactions.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No transactions found.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(filteredTransactions) { tx in
                        let isCredit = tx.type == "TRANSFER_IN" || tx.type == "DEPOSIT" || (tx.amountUsd > 0 && tx.balanceAfter > tx.balanceBefore)
                        let sign = isCredit ? "+" : "-"
                        let color: Color = isCredit ? .green : .red

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(tx.type.replacingOccurrences(of: "_", with: " "))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(4)

                                Spacer()

                                Text("\(sign)$\(String(format: "%.2f", tx.amountUsd))")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(color)
                            }

                            if let desc = tx.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }

                            if let email = tx.counterpartEmail, !email.isEmpty {
                                Text("Counterpart: \(email)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("$\(String(format: "%.2f", tx.balanceBefore)) → $\(String(format: "%.2f", tx.balanceAfter))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(tx.createdAt.prefix(16)).replacingOccurrences(of: "T", with: " "))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .searchable(text: $searchText, prompt: "Search transactions...")
                }
            }
        }
    }
}

// MARK: - Tab 5: Sub-Resellers Tab

public struct ResellerSubResellersTabView: View {
    let subResellers: [SubReseller]
    let onAddSubReseller: () -> Void
    @ObservedObject var lang = LanguageManager.shared

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onAddSubReseller) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(16)

            if subResellers.isEmpty {
                Spacer()
                Text(lang.tr("reseller.subresellers.empty"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(subResellers) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(r.email)
                                .fontWeight(.medium)
                            Spacer()
                            Text("$\(String(format: "%.2f", r.balanceUsd))")
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                        }
                        Text(String(format: lang.tr("reseller.subresellers.stats"), r.customerCount, r.subscriptionCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Reseller Add Sub-Reseller Sheet

public struct ResellerAddSubResellerSheetView: View {
    let balance: Double
    let onCompleted: () -> Void
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lang = LanguageManager.shared
    @State private var email = ""
    @State private var initialBalanceText = "0"
    @State private var isProcessing = false
    @State private var createdPassword: String?
    @State private var errorMessage: String?

    private var initialBalance: Double { Double(initialBalanceText) ?? 0 }
    private var overBudget: Bool { initialBalance > balance }

    public var body: some View {
        NavigationView {
            Form {
                if let pwd = createdPassword {
                    Section(header: Text(lang.tr("reseller.addSubReseller"))) {
                        Text("Share this password with the sub-reseller now:")
                            .font(.caption)
                        HStack {
                            Text(pwd)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Spacer()
                            Button(lang.tr("common.copy")) {
                                UIPasteboard.general.string = pwd
                            }
                        }
                    }
                } else {
                    Section {
                        TextField("Sub-Reseller Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        TextField(lang.tr("reseller.subresellers.initialBalance"), text: $initialBalanceText)
                            .keyboardType(.decimalPad)

                        Text("\(lang.tr("reseller.balance")): $\(String(format: "%.2f", balance))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if overBudget {
                        Section { Text(lang.tr("reseller.insufficientBalance")).foregroundColor(.red).font(.caption) }
                    }

                    if let err = errorMessage {
                        Section { Text(err).foregroundColor(.red).font(.caption) }
                    }

                    Section {
                        Button(action: handleCreate) {
                            HStack {
                                Spacer()
                                if isProcessing { ProgressView().padding(.trailing, 8) }
                                Text(lang.tr("reseller.addSubReseller")).fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .disabled(email.isEmpty || !email.contains("@") || isProcessing || overBudget)
                    }
                }
            }
            .navigationTitle(lang.tr("reseller.addSubReseller"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(createdPassword != nil ? lang.tr("common.done") : lang.tr("common.cancel")) {
                        dismiss()
                        if createdPassword != nil { onCompleted() }
                    }
                }
            }
        }
    }

    private func handleCreate() {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let res = try await ApiClient.shared.createSubReseller(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    initialBalanceUsd: initialBalance
                )
                await MainActor.run {
                    isProcessing = false
                    createdPassword = res.generatedPassword
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Reseller Self Subscription Sheet

public struct ResellerSelfSubSheetView: View {
    let plans: [PlanInfo]
    let balance: Double
    let onCompleted: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlanId = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Choose Personal VPN Plan")) {
                    ForEach(plans) { plan in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.name)
                                Text("\(plan.durationDays) days").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("$\(String(format: "%.2f", plan.priceUsd))")
                                .fontWeight(.bold)
                            if selectedPlanId == plan.id {
                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPlanId = plan.id }
                    }
                }

                if let err = errorMessage {
                    Section { Text(err).foregroundColor(.red).font(.caption) }
                }

                Section {
                    Button(action: handleCreate) {
                        HStack {
                            Spacer()
                            if isProcessing { ProgressView().padding(.trailing, 8) }
                            Text("Confirm & Deduct from Balance").fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(selectedPlanId.isEmpty || isProcessing)
                }
            }
            .navigationTitle("Provision My VPN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if selectedPlanId.isEmpty, let f = plans.first { selectedPlanId = f.id }
            }
        }
    }

    private func handleCreate() {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                _ = try await ApiClient.shared.resellerSelfSubscription(planId: selectedPlanId)
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                    onCompleted()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Reseller Add Customer Sheet

public struct ResellerAddCustomerSheetView: View {
    let onCompleted: () -> Void
    var onCustomerCreated: ((String) -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var customPassword = ""
    @State private var isProcessing = false
    @State private var createdPassword: String?
    @State private var errorMessage: String?

    public var body: some View {
        NavigationView {
            Form {
                if let pwd = createdPassword {
                    Section(header: Text("Customer Account Created")) {
                        Text("Share this password with the customer now:")
                            .font(.caption)
                        HStack {
                            Text(pwd)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = pwd
                            }
                        }
                    }
                } else {
                    Section(header: Text("Customer Credentials")) {
                        TextField("Customer Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("Custom Password (optional)", text: $customPassword)
                    }

                    if let err = errorMessage {
                        Section { Text(err).foregroundColor(.red).font(.caption) }
                    }

                    Section {
                        Button(action: handleCreate) {
                            HStack {
                                Spacer()
                                if isProcessing { ProgressView().padding(.trailing, 8) }
                                Text("Create Customer Account").fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .disabled(email.isEmpty || !email.contains("@") || isProcessing)
                    }
                }
            }
            .navigationTitle("Add Customer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(createdPassword != nil ? "Done" : "Cancel") {
                        dismiss()
                        if createdPassword != nil {
                            onCustomerCreated?(email.trimmingCharacters(in: .whitespacesAndNewlines))
                            onCompleted()
                        }
                    }
                }
            }
        }
    }

    private func handleCreate() {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let res = try await ApiClient.shared.createResellerCustomer(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: customPassword.isEmpty ? nil : customPassword)
                await MainActor.run {
                    isProcessing = false
                    createdPassword = res.generatedPassword
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Reseller Create Order Sheet

public struct ResellerCreateOrderSheetView: View {
    let plans: [PlanInfo]
    let customers: [ResellerCustomer]
    var initialEmail: String = ""
    let balance: Double
    let onCompleted: () -> Void
    var onOrderSuccess: ((CreateResellerOrderResponse) -> Void)? = nil

    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var selectedPlanId = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Customer Email")) {
                    TextField("Enter or select customer email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    if !customers.isEmpty {
                        Picker("Existing Customer", selection: $email) {
                            Text("Select an existing customer").tag("")
                            ForEach(customers) { c in
                                Text(c.email).tag(c.email)
                            }
                        }
                    }
                }

                Section(header: Text("Select Plan")) {
                    ForEach(plans) { plan in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.name)
                                Text("\(plan.durationDays) days").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("$\(String(format: "%.2f", plan.priceUsd))")
                                .fontWeight(.bold)
                            if selectedPlanId == plan.id {
                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPlanId = plan.id }
                    }
                }

                if let err = errorMessage {
                    Section { Text(err).foregroundColor(.red).font(.caption) }
                }

                Section {
                    Button(action: handleCreateOrder) {
                        HStack {
                            Spacer()
                            if isProcessing { ProgressView().padding(.trailing, 8) }
                            Text("Confirm & Pay from Balance").fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(email.isEmpty || selectedPlanId.isEmpty || isProcessing)
                }
            }
            .navigationTitle("Buy Plan for Customer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if !initialEmail.isEmpty { email = initialEmail }
                if selectedPlanId.isEmpty, let f = plans.first { selectedPlanId = f.id }
            }
        }
    }

    private func handleCreateOrder() {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let res = try await ApiClient.shared.createResellerOrder(customerEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), planId: selectedPlanId)
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                    onOrderSuccess?(res)
                    onCompleted()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Reseller Deposit Sheet

public struct ResellerDepositSheetView: View {
    let gateways: GatewayInfo
    let onCompleted: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var amountString = "50"
    @State private var selectedGateway = "MANUAL"
    @State private var isProcessing = false
    @State private var errorMessage: String?

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Deposit Amount (USD)")) {
                    TextField("Amount in USD", text: $amountString)
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Payment Method")) {
                    if gateways.cryptomus {
                        HStack {
                            Text("Cryptomus (USDT/Crypto)")
                            Spacer()
                            if selectedGateway == "CRYPTOMUS" { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedGateway = "CRYPTOMUS" }
                    }

                    if gateways.nowpayments {
                        HStack {
                            Text("NOWPayments")
                            Spacer()
                            if selectedGateway == "NOWPAYMENTS" { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedGateway = "NOWPAYMENTS" }
                    }

                    if gateways.revolut {
                        HStack {
                            Text("Revolut Pay")
                            Spacer()
                            if selectedGateway == "REVOLUT" { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedGateway = "REVOLUT" }
                    }

                    HStack {
                        Text("Manual / Admin Credit")
                        Spacer()
                        if selectedGateway == "MANUAL" { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedGateway = "MANUAL" }
                }

                if let err = errorMessage {
                    Section { Text(err).foregroundColor(.red).font(.caption) }
                }

                Section {
                    Button(action: handleDeposit) {
                        HStack {
                            Spacer()
                            if isProcessing { ProgressView().padding(.trailing, 8) }
                            Text("Deposit Funds").fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled((Double(amountString) ?? 0) <= 0 || isProcessing)
                }
            }
            .navigationTitle("Add Balance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func handleDeposit() {
        guard let amount = Double(amountString), amount > 0 else { return }
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let res = try await ApiClient.shared.createResellerDeposit(amountUsd: amount, gateway: selectedGateway)
                await MainActor.run {
                    isProcessing = false
                    if let urlStr = res.checkoutUrl, let url = URL(string: urlStr) {
                        UIApplication.shared.open(url)
                    }
                    dismiss()
                    onCompleted()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Reseller Customer Detail Sheet

public struct ResellerCustomerDetailSheetView: View {
    let customer: ResellerCustomer
    let onDeleted: () -> Void
    @ObservedObject var lang = LanguageManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var detail: ResellerCustomerDetail?
    @State private var newPasswordInput = ""
    @State private var generatedPasswordResult: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var subscriptionForQR: SubscriptionInfo?
    @State private var copiedSubscriptionId: String?

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Customer Information")) {
                    Text(customer.email).font(.headline)
                    Text("Account ID: \(customer.id)").font(.caption).foregroundColor(.secondary)
                    Text("Created: \(customer.createdAt.prefix(10))").font(.caption).foregroundColor(.secondary)
                }

                Section(header: Text("Active Subscriptions")) {
                    if let subs = detail?.subscriptions, !subs.isEmpty {
                        ForEach(subs) { s in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(s.planName).fontWeight(.medium)
                                Text("Expires: \(s.expiryDate.prefix(10))").font(.caption).foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    Button {
                                        UIPasteboard.general.string = s.subscriptionUrl
                                        copiedSubscriptionId = s.id
                                        Task {
                                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                                            await MainActor.run {
                                                if copiedSubscriptionId == s.id { copiedSubscriptionId = nil }
                                            }
                                        }
                                    } label: {
                                        Label(
                                            copiedSubscriptionId == s.id ? lang.tr("common.copied") : lang.tr("common.copy"),
                                            systemImage: copiedSubscriptionId == s.id ? "checkmark" : "doc.on.doc"
                                        )
                                        .font(.caption)
                                    }
                                    .buttonStyle(.borderless)

                                    Button {
                                        subscriptionForQR = s
                                    } label: {
                                        Label(lang.tr("vpn.qrCode"), systemImage: "qrcode")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.top, 2)
                            }
                        }
                    } else {
                        Text("No active subscriptions").font(.caption).foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Change Password")) {
                    TextField("Set custom password", text: $newPasswordInput)
                    Button("Update Password") {
                        handlePasswordChange(newPassword: newPasswordInput.isEmpty ? nil : newPasswordInput)
                    }
                    .disabled(isProcessing)

                    if let pwd = generatedPasswordResult {
                        HStack {
                            Text("New password: \(pwd)").font(.caption).foregroundColor(.green).fontWeight(.bold)
                            Spacer()
                            Button("Copy") { UIPasteboard.general.string = pwd }
                        }
                    }
                }

                Section {
                    Button(role: .destructive, action: handleDelete) {
                        Text("Delete Customer Account")
                    }
                }
            }
            .navigationTitle("Customer Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    if let d = try? await ApiClient.shared.resellerCustomerDetails(id: customer.id) {
                        await MainActor.run { detail = d }
                    }
                }
            }
            .sheet(item: $subscriptionForQR) { s in
                URLQRCodeSheet(url: s.subscriptionUrl, title: s.planName)
            }
        }
    }

    private func handlePasswordChange(newPassword: String?) {
        isProcessing = true
        Task {
            do {
                let res = try await ApiClient.shared.updateResellerCustomerPassword(id: customer.id, newPassword: newPassword)
                await MainActor.run {
                    isProcessing = false
                    generatedPasswordResult = res.newPassword
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleDelete() {
        Task {
            try? await ApiClient.shared.deleteResellerCustomer(id: customer.id)
            await MainActor.run {
                onDeleted()
            }
        }
    }
}


public struct ResellerConnectionDetails: Identifiable {
    public let id = UUID()
    public let title: String
    public let planName: String
    public let subscriptionUrl: String?
    public let vlessLink: String?
    public let generatedPassword: String?
    public let amountUsd: Double?
    public let expiryDate: String?
    public let status: String?

    public init(
        title: String,
        planName: String,
        subscriptionUrl: String?,
        vlessLink: String?,
        generatedPassword: String? = nil,
        amountUsd: Double? = nil,
        expiryDate: String? = nil,
        status: String? = nil
    ) {
        self.title = title
        self.planName = planName
        self.subscriptionUrl = subscriptionUrl
        self.vlessLink = vlessLink
        self.generatedPassword = generatedPassword
        self.amountUsd = amountUsd
        self.expiryDate = expiryDate
        self.status = status
    }
}

public struct ResellerConnectionQrSheetView: View {
    let details: ResellerConnectionDetails
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lang = LanguageManager.shared
    @State private var qrMode = 0
    @State private var copiedText: String?

    private var activeUrl: String {
        if qrMode == 1, let v = details.vlessLink, !v.isEmpty {
            return v
        }
        return details.subscriptionUrl ?? details.vlessLink ?? ""
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(details.title)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(details.planName)
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.top, 8)

                    if let pwd = details.generatedPassword, !pwd.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Customer Login Credentials")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            HStack {
                                Text("Password: \(pwd)")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                Spacer()
                                Button("Copy") {
                                    UIPasteboard.general.string = pwd
                                    copiedText = "Password"
                                    Task {
                                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                                        await MainActor.run { if copiedText == "Password" { copiedText = nil } }
                                    }
                                }
                                .font(.caption)
                            }
                        }
                        .padding(12)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    if !activeUrl.isEmpty {
                        VStack(spacing: 12) {
                            if details.subscriptionUrl != nil && details.vlessLink != nil {
                                Picker("", selection: $qrMode) {
                                    Text("Sub URL").tag(0)
                                    Text("VLESS Link").tag(1)
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal)
                            }

                            ExternalQRCodeView(
                                content: activeUrl,
                                foregroundColor: .labelColor,
                                backgroundColor: CGColor(gray: 1.0, alpha: 0.0)
                            )
                            .frame(width: 220, height: 220)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
                        }
                    }

                    VStack(spacing: 10) {
                        if let vless = details.vlessLink, !vless.isEmpty {
                            Button {
                                UIPasteboard.general.string = vless
                                copiedText = "VLESS"
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                                    await MainActor.run { if copiedText == "VLESS" { copiedText = nil } }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: copiedText == "VLESS" ? "checkmark" : "doc.on.doc")
                                    Text(copiedText == "VLESS" ? "Copied VLESS Link" : "Copy VLESS Link")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .fontWeight(.semibold)
                            }
                        }

                        if let subUrl = details.subscriptionUrl, !subUrl.isEmpty {
                            Button {
                                UIPasteboard.general.string = subUrl
                                copiedText = "SubURL"
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                                    await MainActor.run { if copiedText == "SubURL" { copiedText = nil } }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: copiedText == "SubURL" ? "checkmark" : "link")
                                    Text(copiedText == "SubURL" ? "Copied Subscription URL" : "Copy Subscription URL")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .foregroundColor(.accentColor)
                                .cornerRadius(12)
                                .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(.horizontal)

                    if let exp = details.expiryDate {
                        Text("Expires: \(exp.prefix(10))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Connection Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
