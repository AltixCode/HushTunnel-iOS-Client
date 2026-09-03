
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

    @State private var selectedTab = 1
    @State private var overview: ResellerOverview? = ResellerOverview(balanceUsd: 250.0, discountPct: 5, nextTier: NextTierInfo(minBalance: 300.0, discountPct: 10), totalCustomers: 8, totalSubscriptions: 12)
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
    @State private var isProvisioning = true
    @State private var provisionError: String?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    // Dialog sheets
    @State private var showChangePasswordSheet = false
    @State private var showDebugLogs = false
    @State private var showSelfSubSheet = false
    @State private var showAddCustomerSheet = false
    @State private var showCreateOrderSheet = false
    @State private var showDepositSheet = false
    @State private var showAddSubResellerSheet = false
    @State private var showLanguagePicker = false
    @State private var selectedCustomerForDetail: ResellerCustomer?
    @State private var prefilledOrderEmail = ""
    @State private var activeConnectionDetails: ResellerConnectionDetails?
    @State private var showTransferFundsSheet = false
    @State private var transferInitialEmail = ""
    @State private var transferLockRecipient = false
    @State private var selectedSubResellerForDetail: SubReseller?
    @State private var showSubResellerDetailSheet = false

    public init() {}

    public var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Tab 0: Personal VPN
                ResellerPersonalVpnTabView(
                    overview: overview,
                    personalSub: personalSubscriptions.first(where: { $0.isActive }),
                    extensionProfile: environments.extensionProfile,
                    provisionError: provisionError,
                    isProvisioning: isProvisioning,
                    servers: servers,
                    selectedServer: selectedServer,
                    prepareForConnect: prepareConnection,
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
                    onExtend: { subId in try await extendSub(id: subId) },
                    onToggle: { subId, enable in try await toggleSub(id: subId, enable: enable) },
                    onResetUuid: { subId in try await resetUuid(id: subId) },
                    onResetTraffic: { subId in try await resetTraffic(id: subId) },
                    onRevoke: { subId in try await revokeSub(id: subId) },
                    onSelectSub: { sub in
                        activeConnectionDetails = ResellerConnectionDetails(
                            title: sub.customerEmail,
                            planName: sub.planName,
                            subscriptionUrl: sub.subscriptionUrl,
                            vlessLink: sub.vlessLink,
                            expiryDate: sub.expiryDate,
                            status: sub.isActive ? "ACTIVE" : "INACTIVE",
                            servers: sub.servers
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
                    currentBalance: overview?.balanceUsd ?? 0,
                    onTransferFunds: {
                        transferInitialEmail = ""
                        transferLockRecipient = false
                        showTransferFundsSheet = true
                    },
                    onSelectOrder: { order in
                        activeConnectionDetails = ResellerConnectionDetails(
                            title: order.customerEmail,
                            planName: order.planName,
                            subscriptionUrl: order.subscriptionUrl,
                            vlessLink: order.vlessLink,
                            amountUsd: order.amountUsd,
                            status: order.status,
                            servers: order.servers
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
                    onAddSubReseller: { showAddSubResellerSheet = true },
                    onSelectSubReseller: { r in
                        selectedSubResellerForDetail = r
                        showSubResellerDetailSheet = true
                    },
                    onAddFunds: { r in
                        transferInitialEmail = r.email
                        transferLockRecipient = true
                        showTransferFundsSheet = true
                    }
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
                    .accessibilityIdentifier("hush.language-picker")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showDebugLogs = true
                        } label: {
                            Image(systemName: "ladybug")
                        }

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
            .sheet(isPresented: $showDebugLogs) {
                NavigationStack {
                    LogView()
                        .navigationTitle(lang.tr("debug.logsTitle"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(lang.tr("common.done")) { showDebugLogs = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showServerPickerSheet) {
                ServerPickerSheetView(
                    servers: servers,
                    selectedServer: selectedServer,
                    onSelect: { s in
                        isProvisioning = true
                        Task {
                            if let activeSub = personalSubscriptions.first(where: { $0.isActive }) {
                                do {
                                    let wasConnected = await MainActor.run {
                                        environments.extensionProfile?.status == .connected
                                    }
                                    try await ProvisionHelper.provisionSubscription(
                                        subscriptionUrl: activeSub.subscriptionUrl,
                                        preferredServerId: s.id,
                                        reloadRunningProfile: false
                                    )
                                    await environments.reload()
                                    await MainActor.run {
                                        selectedServer = s
                                        provisionError = nil
                                    }
                                    if wasConnected {
                                        try await environments.extensionProfile?.restart()
                                    }
                                    await MainActor.run { isProvisioning = false }
                                } catch {
                                    print("Error switching server: \(error)")
                                    await MainActor.run {
                                        provisionError = error.localizedDescription
                                        isProvisioning = false
                                    }
                                }
                            } else {
                                await MainActor.run { isProvisioning = false }
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
                            amountUsd: res.amountUsd,
                            servers: res.servers
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
            .sheet(item: $selectedCustomerForDetail) { customer in
                ResellerCustomerDetailSheetView(customer: customer, onDeleted: {
                    selectedCustomerForDetail = nil
                    refreshAll()
                })
            }
            .sheet(isPresented: $showTransferFundsSheet) {
                ResellerTransferFundsSheetView(
                    balance: overview?.balanceUsd ?? 0,
                    initialEmail: transferInitialEmail,
                    lockRecipient: transferLockRecipient,
                    onCompleted: refreshAll
                )
            }
            .sheet(isPresented: $showSubResellerDetailSheet) {
                if let sub = selectedSubResellerForDetail {
                    ResellerSubResellerDetailSheetView(
                        subReseller: sub,
                        currentBalance: overview?.balanceUsd ?? 0,
                        onAddFunds: { targetReseller in
                            showSubResellerDetailSheet = false
                            transferInitialEmail = targetReseller.email
                            transferLockRecipient = true
                            showTransferFundsSheet = true
                        }
                    )
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
        isProvisioning = true
        errorMessage = nil
        Task {
            let ov = try? await ApiClient.shared.resellerOverview()
            let cust = try? await ApiClient.shared.resellerCustomers()
            let sub = try? await ApiClient.shared.resellerSubscriptions()
            let me = try? await ApiClient.shared.me()
            let ord = try? await ApiClient.shared.resellerOrders()
            let dep = try? await ApiClient.shared.resellerDeposits()
            let pl = try? await ApiClient.shared.plans()
            let gw = try? await ApiClient.shared.gateways()
            let subRes = try? await ApiClient.shared.resellerSubResellers()
            let tx = try? await ApiClient.shared.walletTransactions()

            await MainActor.run {
                if let ov { self.overview = ov }
                if let cust { self.customers = cust }
                if let sub { self.subscriptions = sub }
                if let me {
                    self.personalSubscriptions = me.subscriptions
                    if let srv = me.servers {
                        self.servers = srv
                        self.selectedServer = ServerSelectionStore.resolve(
                            servers: srv,
                            currentServerID: self.selectedServer?.id
                        )
                    }
                }
                if let ord { self.orders = ord }
                if let dep { self.deposits = dep }
                if let pl { self.plans = pl }
                if let gw { self.gateways = gw }
                if let subRes { self.subResellers = subRes }
                if let tx { self.transactions = tx }
                self.isLoading = false
            }

            if let activeSub = me?.subscriptions.first(where: { $0.isActive }) {
                do {
                    guard let serverID = await MainActor.run(body: { self.selectedServer?.id }) else {
                        throw NSError(domain: "HushTunnel", code: 2, userInfo: [NSLocalizedDescriptionKey: lang.tr("vpn.noServer")])
                    }
                    try await ProvisionHelper.provisionSubscription(
                        subscriptionUrl: activeSub.subscriptionUrl,
                        preferredServerId: serverID
                    )
                    await environments.reload()
                    await MainActor.run {
                        self.provisionError = nil
                        self.isProvisioning = false
                    }
                } catch {
                    await MainActor.run {
                        self.provisionError = error.localizedDescription
                        self.isProvisioning = false
                    }
                }
            } else {
                await MainActor.run { self.isProvisioning = false }
            }
        }
    }

    private func prepareConnection() async throws {
        guard let activeSub = personalSubscriptions.first(where: { $0.isActive }),
              let server = selectedServer ?? servers.first(where: { $0.isDefault == true }) ?? servers.first
        else {
            throw NSError(domain: "HushTunnel", code: 1, userInfo: [NSLocalizedDescriptionKey: lang.tr("vpn.noSub")])
        }
        try await ProvisionHelper.provisionSubscription(
            subscriptionUrl: activeSub.subscriptionUrl,
            preferredServerId: server.id
        )
    }

    private func extendSub(id: String) async throws {
        try await ApiClient.shared.extendResellerSubscription(id: id, days: 30)
        refreshAll()
    }

    private func toggleSub(id: String, enable: Bool) async throws {
        try await ApiClient.shared.toggleResellerSubscription(id: id, enable: enable)
        refreshAll()
    }

    private func resetUuid(id: String) async throws {
        try await ApiClient.shared.resetResellerSubscriptionUuid(id: id)
        refreshAll()
    }

    private func resetTraffic(id: String) async throws {
        try await ApiClient.shared.resetResellerSubscriptionTraffic(id: id)
        refreshAll()
    }

    private func revokeSub(id: String) async throws {
        try await ApiClient.shared.revokeResellerSubscription(id: id)
        refreshAll()
    }
}

// MARK: - Tab 0: Personal VPN Tab

public struct ResellerPersonalVpnTabView: View {
    let overview: ResellerOverview?
    let personalSub: SubscriptionInfo?
    let extensionProfile: ExtensionProfile?
    let provisionError: String?
    let isProvisioning: Bool
    let servers: [ServerNodeItem]
    let selectedServer: ServerNodeItem?
    let prepareForConnect: () async throws -> Void
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
                    ConnectCircleButton(
                        profile: profile,
                        isProvisioning: isProvisioning,
                        prepareForConnect: prepareForConnect
                    )
                        .padding(.top, 24)
                    ConnectStatusLabel(profile: profile, isProvisioning: isProvisioning)
                    let currentServer = selectedServer ?? servers.first(where: { $0.isDefault == true }) ?? servers.first
                    ConnectionTestView(profile: profile, expectedHost: currentServer?.host ?? "")
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
                .disabled(isProvisioning)

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

                        Text("Plan: \(sub.planName) · Expires: \(DateUtils.formatDateWithShamsi(sub.expiryDate))")
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
                Button {
                    onSelectCustomer(customer)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(customer.email)
                                .foregroundColor(.primary)

                            Text("Created: \(DateUtils.formatDateWithShamsi(customer.createdAt))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hush.reseller.customer-row")
            }
            .id("customers-\(lang.currentLanguage.rawValue)")
        }
    }
}

// MARK: - Tab 3: Subscriptions Tab

public struct ResellerSubscriptionsTabView: View {
    let subscriptions: [ResellerSubscription]
    let onExtend: (String) async throws -> Void
    let onToggle: (String, Bool) async throws -> Void
    let onResetUuid: (String) async throws -> Void
    let onResetTraffic: (String) async throws -> Void
    let onRevoke: (String) async throws -> Void
    var onSelectSub: ((ResellerSubscription) -> Void)? = nil
    @State private var search = ""
    @ObservedObject var lang = LanguageManager.shared

    // Tracks which (subscriptionId, action) is currently in flight so only the
    // tapped button shows a spinner, not every button on every row.
    @State private var pendingAction: (String, String)?
    // Disabling a subscription cuts a real customer's access, resetting the
    // UUID breaks their existing VLESS link/QR immediately, and revoking
    // deletes the subscription outright — all three need explicit confirmation
    // before firing.
    @State private var confirmTarget: (id: String, email: String, kind: String)?
    @State private var errorMessage: String?

    private var filtered: [ResellerSubscription] {
        if search.isEmpty { return subscriptions }
        let q = search.lowercased()
        return subscriptions.filter {
            $0.customerEmail.lowercased().contains(q) ||
            $0.planName.lowercased().contains(q)
        }
    }

    private func run(_ id: String, _ kind: String, _ action: @escaping () async throws -> Void) {
        pendingAction = (id, kind)
        errorMessage = nil
        Task {
            do {
                try await action()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { pendingAction = nil }
        }
    }

    @ViewBuilder
    private func actionLabel(_ id: String, _ kind: String, _ text: String) -> some View {
        if pendingAction?.0 == id && pendingAction?.1 == kind {
            ProgressView().scaleEffect(0.7)
        } else {
            Text(text)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }

            TextField(lang.tr("reseller.searchSubscriptions"), text: $search)
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)
                .padding(16)

            List(filtered) { sub in
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    onSelectSub?(sub)
                } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sub.customerEmail)

                        Text("\(sub.planName) · Expires \(DateUtils.formatDateWithShamsi(sub.expiryDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(sub.isActive ? lang.tr("reseller.subStatusActive") : lang.tr("reseller.subStatusDisabled"))
                        .font(.caption2)

                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(sub.isActive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .foregroundColor(sub.isActive ? .green : .red)
                        .cornerRadius(6)
                }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityIdentifier("hush.reseller.subscription-row")

                // Action Row
                HStack(spacing: 8) {
                    Button {
                        run(sub.id, "extend") { try await onExtend(sub.id) }
                    } label: {
                        actionLabel(sub.id, "extend", lang.tr("reseller.extend"))
                    }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(6)
                        .disabled(pendingAction != nil)

                    Button {
                        if sub.isActive {
                            confirmTarget = (sub.id, sub.customerEmail, "disable")
                        } else {
                            run(sub.id, "toggle") { try await onToggle(sub.id, true) }
                        }
                    } label: {
                        actionLabel(sub.id, "toggle", sub.isActive ? lang.tr("reseller.toggleDisable") : lang.tr("reseller.toggleEnable"))
                    }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(6)
                        .disabled(pendingAction != nil)

                    Button {
                        confirmTarget = (sub.id, sub.customerEmail, "resetUuid")
                    } label: {
                        actionLabel(sub.id, "resetUuid", lang.tr("reseller.resetUuid"))
                    }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(6)
                        .disabled(pendingAction != nil)

                    Spacer()

                    Button {
                        confirmTarget = (sub.id, sub.customerEmail, "revoke")
                    } label: {
                        actionLabel(sub.id, "revoke", lang.tr("reseller.revoke"))
                    }
                        .font(.caption2)
                        .foregroundColor(.red)
                        .disabled(pendingAction != nil)
                }
            }
            .padding(.vertical, 6)
        }
        .id("subscriptions-\(lang.currentLanguage.rawValue)")
        }
        .alert(
            confirmTargetTitle,
            isPresented: Binding(get: { confirmTarget != nil }, set: { if !$0 { confirmTarget = nil } }),
            presenting: confirmTarget
        ) { target in
            Button(lang.tr("common.cancel"), role: .cancel) {}
            Button(lang.tr("common.confirm"), role: .destructive) {
                switch target.kind {
                case "disable":
                    run(target.id, "toggle") { try await onToggle(target.id, false) }
                case "resetUuid":
                    run(target.id, "resetUuid") { try await onResetUuid(target.id) }
                case "revoke":
                    run(target.id, "revoke") { try await onRevoke(target.id) }
                default:
                    break
                }
            }
        } message: { target in
            Text(String(format: confirmTargetMessageFormat, target.email))
        }
    }

    private var confirmTargetTitle: String {
        switch confirmTarget?.kind {
        case "disable": return lang.tr("reseller.confirmDisableSubTitle")
        case "resetUuid": return lang.tr("reseller.confirmResetUuidTitle")
        case "revoke": return lang.tr("reseller.confirmRevokeTitle")
        default: return ""
        }
    }

    private var confirmTargetMessageFormat: String {
        switch confirmTarget?.kind {
        case "disable": return lang.tr("reseller.confirmDisableSubMessage")
        case "resetUuid": return lang.tr("reseller.confirmResetUuidMessage")
        case "revoke": return lang.tr("reseller.confirmRevokeMessage")
        default: return "%@"
        }
    }
}

// MARK: - Tab 4: Orders and Deposits Tab

public struct ResellerOrdersAndTransactionsTabView: View {
    let orders: [ResellerOrder]
    let transactions: [WalletTransactionItem]
    var currentBalance: Double = 0
    var onTransferFunds: (() -> Void)? = nil
    var onSelectOrder: ((ResellerOrder) -> Void)? = nil
    @ObservedObject var lang = LanguageManager.shared
    @State private var section = 0
    @State private var searchText = ""

    var filteredOrders: [ResellerOrder] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return orders
        }
        let q = searchText.lowercased()
        return orders.filter {
            $0.customerEmail.lowercased().contains(q) ||
            $0.planName.lowercased().contains(q) ||
            $0.status.lowercased().contains(q)
        }
    }

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

    /// Renders a wallet transaction's description, preferring the localized
    /// `descriptionKey`/`params` pair (server-driven i18n) and falling back
    /// to the raw English `description` for legacy rows or free-text notes.
    func renderedDescription(for tx: WalletTransactionItem) -> String {
        guard let key = tx.descriptionKey else {
            return tx.description ?? ""
        }
        let params = tx.params ?? [:]
        switch key {
        case "tx.transferOut":
            return String(format: lang.tr(key), params["email"] ?? "")
        case "tx.transferIn":
            return String(format: lang.tr(key), params["email"] ?? "")
        case "tx.deposit":
            return String(format: lang.tr(key), params["depositId"] ?? "")
        case "tx.planPurchase":
            return String(format: lang.tr(key), params["planName"] ?? "")
        case "tx.orderPayment":
            return String(format: lang.tr(key), params["orderId"] ?? "")
        case "tx.personalSubscription":
            return String(format: lang.tr(key), params["planName"] ?? "")
        case "tx.personalRenewal":
            return String(format: lang.tr(key), params["planName"] ?? "")
        case "tx.createdAccountOrder":
            return String(format: lang.tr(key), params["email"] ?? "", params["planName"] ?? "")
        case "tx.orderForCustomer":
            return String(format: lang.tr(key), params["email"] ?? "", params["planName"] ?? "")
        case "tx.subResellerInitialBalance":
            return String(format: lang.tr(key), params["email"] ?? "")
        case "tx.startupBalanceFromParent":
            return lang.tr(key)
        default:
            return tx.description ?? ""
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
                    List(filteredOrders) { order in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.customerEmail)
                                    
                                Text("\(order.planName) · \(DateUtils.formatDateWithShamsi(order.createdAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("$\(String(format: "%.2f", order.amountUsd))")
                                    
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
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang.tr("reseller.balance"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(String(format: "%.2f", currentBalance))")
                                .font(.title3)
                                
                                .foregroundColor(.accentColor)
                        }
                        Spacer()
                        Button(action: { onTransferFunds?() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.left.arrow.right")
                                Text(lang.tr("reseller.transferFunds"))
                            }
                            .font(.subheadline)
                            
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.08))

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
                                    
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(4)

                                Spacer()

                                Text("\(sign)$\(String(format: "%.2f", tx.amountUsd))")
                                    .font(.subheadline)
                                    
                                    .foregroundColor(color)
                            }

                            let desc = renderedDescription(for: tx)
                            if !desc.isEmpty {
                                Text(desc)
                                    .font(.subheadline)

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
                                Text(String(tx.createdAt.prefix(16)).replacingOccurrences(of: "T", with: " ") + (DateUtils.formatShamsiOnly(tx.createdAt).map { " (\($0))" } ?? ""))
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
}

// MARK: - Tab 5: Sub-Resellers Tab

public struct ResellerSubResellersTabView: View {
    let subResellers: [SubReseller]
    let onAddSubReseller: () -> Void
    var onSelectSubReseller: ((SubReseller) -> Void)? = nil
    var onAddFunds: ((SubReseller) -> Void)? = nil
    @ObservedObject var lang = LanguageManager.shared
    @State private var search = ""

    private var filtered: [SubReseller] {
        if search.isEmpty { return subResellers }
        return subResellers.filter { $0.email.localizedCaseInsensitiveContains(search) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search sub-resellers...", text: $search)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(10)

                Button(action: onAddSubReseller) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(16)

            if filtered.isEmpty {
                Spacer()
                Text(lang.tr("reseller.subresellers.empty"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(filtered) { r in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.email)
                                    
                                Text(String(format: lang.tr("reseller.subresellers.stats"), r.customerCount, r.subscriptionCount))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("$\(String(format: "%.2f", r.balanceUsd))")
                                    
                                    .foregroundColor(.accentColor)
                                Button(action: { onAddFunds?(r) }) {
                                    Text(lang.tr("reseller.subresellers.addFunds"))
                                        .font(.caption2)
                                        
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundColor(.green)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectSubReseller?(r)
                    }
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
        NavigationStack {
            Form {
                if let pwd = createdPassword {
                    Section(header: Text(lang.tr("reseller.addSubReseller"))) {
                        Text("Share this password with the sub-reseller now:")
                            .font(.caption)
                        HStack {
                            Text(pwd)
                                .font(.system(.body, design: .monospaced))
                                
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

                        EmailDomainChipsView(email: $email)

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
                                Text(lang.tr("reseller.addSubReseller"))
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
        NavigationStack {
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
                            Text("Confirm & Deduct from Balance")
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
        NavigationStack {
            Form {
                if let pwd = createdPassword {
                    Section(header: Text("Customer Account Created")) {
                        Text("Share this password with the customer now:")
                            .font(.caption)
                        HStack {
                            Text(pwd)
                                .font(.system(.body, design: .monospaced))
                                
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

                        EmailDomainChipsView(email: $email)

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
                                Text("Create Customer Account")
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
    @ObservedObject var lang = LanguageManager.shared
    @State private var email = ""
    @State private var customerSearch = ""
    @State private var selectedPlanId = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Customer Email")) {
                    TextField("Enter or select customer email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    EmailDomainChipsView(email: $email)

                    if !customers.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField(lang.tr("reseller.searchExistingCustomer"), text: $customerSearch)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .accessibilityIdentifier("hush.reseller.order-customer-search")
                        }

                        let matching = customers.filter { customer in
                            customerSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                customer.email.localizedCaseInsensitiveContains(customerSearch)
                        }
                        if matching.isEmpty {
                            Text(lang.tr("reseller.noMatchingCustomers"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(matching.prefix(12)) { customer in
                                Button {
                                    email = customer.email
                                    customerSearch = customer.email
                                } label: {
                                    HStack {
                                        Text(customer.email)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if email.caseInsensitiveCompare(customer.email) == .orderedSame {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
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
                            Text("Confirm & Pay from Balance")
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
                if !initialEmail.isEmpty {
                    email = initialEmail
                    customerSearch = initialEmail
                }
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
        NavigationStack {
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
                            Text("Deposit Funds")
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
    @State private var isLoadingDetail = true
    @State private var detailError: String?
    @State private var newPasswordInput = ""
    @State private var generatedPasswordResult: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var subscriptionForQR: SubscriptionInfo?
    @State private var copiedSubscriptionId: String?

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Customer Information")) {
                    Text(customer.email).font(.headline)
                    Text("Account ID: \(customer.id)").font(.caption).foregroundColor(.secondary)
                    Text("Created: \(DateUtils.formatDateWithShamsi(customer.createdAt))").font(.caption).foregroundColor(.secondary)
                }

                Section(header: Text("Active Subscriptions")) {
                    if isLoadingDetail {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if let detailError {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(detailError)
                                .font(.caption)
                                .foregroundColor(.red)
                            Button(lang.tr("common.refresh")) {
                                Task { await loadDetail() }
                            }
                        }
                    } else if let subs = detail?.subscriptions, !subs.isEmpty {
                        ForEach(subs) { s in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(s.planName)
                                Text("Expires: \(DateUtils.formatDateWithShamsi(s.expiryDate))").font(.caption).foregroundColor(.secondary)

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
                            Text("New password: \(pwd)").font(.caption).foregroundColor(.green)
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
            .accessibilityIdentifier("hush.reseller.customer-detail")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: customer.id) { await loadDetail() }
            .sheet(item: $subscriptionForQR) { s in
                URLQRCodeSheet(url: s.subscriptionUrl, title: s.planName)
            }
        }
    }

    @MainActor
    private func loadDetail() async {
        isLoadingDetail = true
        detailError = nil
        do {
            detail = try await ApiClient.shared.resellerCustomerDetails(id: customer.id)
        } catch {
            detailError = error.localizedDescription
        }
        isLoadingDetail = false
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
    public let servers: [ResellerServerLink]

    public init(
        title: String,
        planName: String,
        subscriptionUrl: String?,
        vlessLink: String?,
        generatedPassword: String? = nil,
        amountUsd: Double? = nil,
        expiryDate: String? = nil,
        status: String? = nil,
        servers: [ResellerServerLink] = []
    ) {
        self.title = title
        self.planName = planName
        self.subscriptionUrl = subscriptionUrl
        self.vlessLink = vlessLink
        self.generatedPassword = generatedPassword
        self.amountUsd = amountUsd
        self.expiryDate = expiryDate
        self.status = status
        self.servers = servers
    }
}

public struct ResellerConnectionQrSheetView: View {
    let details: ResellerConnectionDetails
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lang = LanguageManager.shared
    @State private var copiedText: String?
    @State private var showAdvanced = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(details.title)
                            .font(.headline)
                            
                        Text(details.planName)
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.top, 8)

                    if let pwd = details.generatedPassword, !pwd.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Customer Login Credentials")
                                .font(.caption)
                                
                                .foregroundColor(.primary)
                            HStack {
                                Text("Password: \(pwd)")
                                    .font(.system(.body, design: .monospaced))
                                    
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

                    // Subscription URL: one aggregate link that works across every
                    // server, shown as the primary QR + copy action — the per-server
                    // VLESS links below are collapsed behind an advanced toggle since
                    // mainstream clients (including our own apps and V2Box) import the
                    // subscription URL directly and get real DNS routing from it, unlike
                    // a bare vless:// link.
                    if let subUrl = details.subscriptionUrl, !subUrl.isEmpty {
                        ExternalQRCodeView(
                            content: subUrl,
                            foregroundColor: CGColor(gray: 0.0, alpha: 1.0),
                            backgroundColor: CGColor(gray: 1.0, alpha: 1.0)
                        )
                        .accessibilityIdentifier("hush.reseller.sub-qr-code")
                        .frame(width: 220, height: 220)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)

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
                        }
                        .padding(.horizontal)

                        Button {
                            withAnimation { showAdvanced.toggle() }
                        } label: {
                            HStack {
                                Text(showAdvanced ? lang.tr("reseller.hideAdvancedLinks") : lang.tr("reseller.showAdvancedLinks"))
                                Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            }
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }

                    // Per-server VLESS links: one card per active edge server,
                    // default-first, exactly in the order the API returned them.
                    // Collapsed by default when a subscription URL is available (see above).
                    if showAdvanced || details.subscriptionUrl?.isEmpty != false {
                        if details.subscriptionUrl?.isEmpty == false {
                            Text(lang.tr("reseller.advancedLinksHint"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        if !details.servers.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(details.servers) { server in
                                    ResellerServerLinkRowView(server: server)
                                }
                            }
                        } else if let vless = details.vlessLink, !vless.isEmpty {
                            // Defensive fallback for older cached responses that
                            // predate the `servers` array — single VLESS link only.
                            VStack(spacing: 12) {
                                ExternalQRCodeView(
                                    content: vless,
                                    foregroundColor: CGColor(gray: 0.0, alpha: 1.0),
                                    backgroundColor: CGColor(gray: 1.0, alpha: 1.0)
                                )
                                .accessibilityIdentifier("hush.reseller.qr-code")
                                .frame(width: 220, height: 220)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)

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
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    if let exp = details.expiryDate {
                        Text("Expires: \(DateUtils.formatDateWithShamsi(exp))")
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

// MARK: - Per-server VLESS link row

// One card per active edge server for a customer's connection: flag, name,
// city/country, an optional "Default" badge, that server's own QR code, and
// a copy button scoped to that server's own vlessLink. Each row is its own
// SwiftUI View instance holding `server` as a `let` and `copied` as its own
// @State, so there is no shared/stale-closure state across ForEach rows —
// every row's button captures only its own server value.
private struct ResellerServerLinkRowView: View {
    let server: ResellerServerLink
    @ObservedObject var lang = LanguageManager.shared
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(server.flag)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(server.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if server.isDefault {
                            Text(lang.tr("reseller.serverDefault"))
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }

                    Text(server.city ?? server.countryCode)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            ExternalQRCodeView(
                content: server.vlessLink,
                foregroundColor: CGColor(gray: 0.0, alpha: 1.0),
                backgroundColor: CGColor(gray: 1.0, alpha: 1.0)
            )
            .accessibilityIdentifier("hush.reseller.qr-code")
            .frame(width: 180, height: 180)
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)

            Button {
                UIPasteboard.general.string = server.vlessLink
                copied = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run { copied = false }
                }
            } label: {
                HStack {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "Copied VLESS Link" : "Copy VLESS Link")
                        
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Reseller Transfer Funds Sheet

public struct ResellerTransferFundsSheetView: View {
    let balance: Double
    var initialEmail: String = ""
    var lockRecipient: Bool = false
    let onCompleted: () -> Void
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lang = LanguageManager.shared
    @State private var recipientEmail = ""
    @State private var amountString = ""
    @State private var note = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var amount: Double { Double(amountString) ?? 0 }
    private var isOverBalance: Bool { amount > balance }
    private var remainingBalance: Double { max(0, balance - amount) }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(lang.tr("reseller.transferFunds")), footer: Text("Instant zero-fee transfer to any user or sub-reseller")) {
                    TextField(lang.tr("reseller.transfer.recipientEmail"), text: $recipientEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(lockRecipient)
                        .foregroundColor(lockRecipient ? .secondary : .primary)

                    if !lockRecipient {
                        EmailDomainChipsView(email: $recipientEmail)
                    }

                    HStack {
                        TextField(lang.tr("reseller.transfer.amountUsd"), text: $amountString)
                            .keyboardType(.decimalPad)
                        Spacer()
                        Button("Max") {
                            amountString = String(format: "%.2f", balance)
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }

                    // Quick chip buttons
                    HStack(spacing: 8) {
                        ForEach([5, 10, 25, 50], id: \.self) { quickVal in
                            Button("+\(quickVal)") {
                                let newAmt = min(Double(quickVal), balance)
                                amountString = String(format: "%.2f", newAmt)
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                            .disabled(balance < Double(quickVal))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    TextField(lang.tr("reseller.transfer.note"), text: $note)
                }

                Section(header: Text("Balance Summary")) {
                    HStack {
                        Text(String(format: lang.tr("reseller.transfer.availableBalance"), String(format: "%.2f", balance)))
                            .font(.subheadline)
                            
                        Spacer()
                    }

                    if amount > 0 {
                        HStack {
                            Text(String(format: lang.tr("reseller.transfer.remainingBalance"), String(format: "%.2f", remainingBalance)))
                                .font(.caption)
                                .foregroundColor(isOverBalance ? .red : .secondary)
                            Spacer()
                        }
                    }
                }

                if isOverBalance {
                    Section { Text(lang.tr("reseller.insufficientBalance")).foregroundColor(.red).font(.caption) }
                }

                if let err = errorMessage {
                    Section { Text(err).foregroundColor(.red).font(.caption) }
                }

                if let msg = successMessage {
                    Section { Text(msg).foregroundColor(.green).font(.caption) }
                }

                Section {
                    Button(action: handleTransfer) {
                        HStack {
                            Spacer()
                            if isProcessing { ProgressView().padding(.trailing, 8) }
                            Text(lang.tr("reseller.transfer.confirm"))
                            Spacer()
                        }
                    }
                    .disabled(recipientEmail.isEmpty || !recipientEmail.contains("@") || amount <= 0 || isOverBalance || isProcessing)
                }
            }
            .navigationTitle(lang.tr("reseller.transferFunds"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.tr("common.cancel")) { dismiss() }
                }
            }
            .onAppear {
                if !initialEmail.isEmpty {
                    recipientEmail = initialEmail
                }
            }
        }
    }

    private func handleTransfer() {
        guard !recipientEmail.isEmpty, amount > 0, !isOverBalance else { return }
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        Task {
            do {
                _ = try await ApiClient.shared.transferFunds(
                    recipientEmail: recipientEmail,
                    amountUsd: amount,
                    description: note.isEmpty ? nil : note
                )
                await MainActor.run {
                    isProcessing = false
                    successMessage = lang.tr("reseller.transfer.success")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        dismiss()
                        onCompleted()
                    }
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

// MARK: - Reseller Sub-Reseller Detail Sheet

public struct ResellerSubResellerDetailSheetView: View {
    let subReseller: SubReseller
    let currentBalance: Double
    let onAddFunds: (SubReseller) -> Void
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lang = LanguageManager.shared

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(lang.tr("reseller.subresellers.details"))) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subReseller.email).font(.headline)
                        Text("Sub-Reseller Partner")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }

                    HStack {
                        Text(lang.tr("reseller.balance"))
                        Spacer()
                        Text("$\(String(format: "%.2f", subReseller.balanceUsd))")
                            
                            .foregroundColor(.green)
                    }

                    HStack {
                        Text(lang.tr("reseller.tab.customers"))
                        Spacer()
                        Text("\(subReseller.customerCount)")
                            
                    }

                    HStack {
                        Text(lang.tr("reseller.tab.subscriptions"))
                        Spacer()
                        Text("\(subReseller.subscriptionCount)")
                            
                    }

                    HStack {
                        Text("Joined")
                        Spacer()
                        Text(DateUtils.formatDateWithShamsi(subReseller.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(action: {
                        dismiss()
                        onAddFunds(subReseller)
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "plus.circle")
                            Text(lang.tr("reseller.subresellers.addFunds"))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(lang.tr("reseller.subresellers.details"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.tr("common.close")) { dismiss() }
                }
            }
        }
    }
}


// MARK: - Email Domain Chips Helper

public struct EmailDomainChipsView: View {
    @Binding var email: String
    private let domains = ["@gmail.com", "@yahoo.com", "@outlook.com", "@icloud.com", "@proton.me", "@hotmail.com"]

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(domains, id: \.self) { domain in
                    Button(action: {
                        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let atIdx = clean.firstIndex(of: "@") {
                            email = String(clean[..<atIdx]) + domain
                        } else {
                            email = clean + domain
                        }
                    }) {
                        Text(domain)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundColor(.accentColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }
}
