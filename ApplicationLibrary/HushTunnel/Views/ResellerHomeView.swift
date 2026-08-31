import SwiftUI

public struct ResellerHomeView: View {
    @ObservedObject var authStore = AuthStore.shared
    @ObservedObject var lang = LanguageManager.shared

    @State private var selectedTab = 0
    @State private var overview: ResellerOverview?
    @State private var customers: [ResellerCustomer] = []
    @State private var subscriptions: [ResellerSubscription] = []
    @State private var orders: [ResellerOrder] = []
    @State private var deposits: [ResellerDeposit] = []
    @State private var plans: [PlanInfo] = []
    @State private var gateways = GatewayInfo()

    @State private var isLoading = false
    @State private var isConnected = false
    @State private var isConnecting = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    // Dialog sheets
    @State private var showChangePasswordSheet = false
    @State private var showSelfSubSheet = false
    @State private var showAddCustomerSheet = false
    @State private var showCreateOrderSheet = false
    @State private var showDepositSheet = false
    @State private var showLanguagePicker = false
    @State private var selectedCustomerForDetail: ResellerCustomer?
    @State private var showCustomerDetailSheet = false

    public init() {}

    public var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Tab 0: Personal VPN
                ResellerPersonalVpnTabView(
                    overview: overview,
                    personalSub: subscriptions.first(where: { $0.isSelf == true }),
                    isConnected: isConnected,
                    isConnecting: isConnecting,
                    onToggleConnect: toggleConnection,
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
                    onRevoke: { subId in revokeSub(id: subId) }
                )
                .tabItem {
                    Label(lang.tr("reseller.tab.subscriptions"), systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(3)

                // Tab 4: Orders & Deposits
                ResellerOrdersAndDepositsTabView(
                    orders: orders,
                    deposits: deposits,
                    onAddDeposit: { showDepositSheet = true }
                )
                .tabItem {
                    Label(lang.tr("reseller.tab.orders"), systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(4)
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
            .sheet(isPresented: $showSelfSubSheet) {
                ResellerSelfSubSheetView(plans: plans, balance: overview?.balanceUsd ?? 0, onCompleted: refreshAll)
            }
            .sheet(isPresented: $showAddCustomerSheet) {
                ResellerAddCustomerSheetView(onCompleted: refreshAll)
            }
            .sheet(isPresented: $showCreateOrderSheet) {
                ResellerCreateOrderSheetView(plans: plans, customers: customers, balance: overview?.balanceUsd ?? 0, onCompleted: refreshAll)
            }
            .sheet(isPresented: $showDepositSheet) {
                ResellerDepositSheetView(gateways: gateways, onCompleted: refreshAll)
            }
            .sheet(isPresented: $showCustomerDetailSheet) {
                if let c = selectedCustomerForDetail {
                    ResellerCustomerDetailSheetView(customer: c, onDeleted: {
                        showCustomerDetailSheet = false
                        refreshAll()
                    })
                }
            }
            .onAppear(perform: refreshAll)
        }
    }

    private func toggleConnection() {
        if isConnected {
            isConnected = false
        } else {
            isConnecting = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isConnecting = false
                isConnected = true
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
                async let ordTask = ApiClient.shared.resellerOrders()
                async let depTask = ApiClient.shared.resellerDeposits()
                async let plTask = ApiClient.shared.plans()
                async let gwTask = ApiClient.shared.gateways()

                let (ov, cust, sub, ord, dep, pl, gw) = try await (ovTask, custTask, subTask, ordTask, depTask, plTask, gwTask)

                await MainActor.run {
                    self.overview = ov
                    self.customers = cust
                    self.subscriptions = sub
                    self.orders = ord
                    self.deposits = dep
                    self.plans = pl
                    self.gateways = gw
                    self.isLoading = false
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
    let personalSub: ResellerSubscription?
    let isConnected: Bool
    let isConnecting: Bool
    let onToggleConnect: () -> Void
    let onCreateSelfSub: () -> Void
    @ObservedObject var lang = LanguageManager.shared

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Connect Circle
                Button(action: onToggleConnect) {
                    ZStack {
                        Circle()
                            .fill(isConnected ? Color.green : (isConnecting ? Color.orange : Color.accentColor))
                            .frame(width: 140, height: 140)
                            .shadow(color: (isConnected ? Color.green : Color.accentColor).opacity(0.35), radius: 20, x: 0, y: 10)

                        VStack(spacing: 6) {
                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.4)
                            } else {
                                Image(systemName: isConnected ? "lock.shield.fill" : "power")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text(isConnecting ? lang.tr("vpn.connecting") : (isConnected ? lang.tr("vpn.disconnect") : lang.tr("vpn.connect")))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.top, 24)

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

                    Button(action: onAddFunds) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(lang.tr("reseller.addFunds"))
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

public struct ResellerOrdersAndDepositsTabView: View {
    let orders: [ResellerOrder]
    let deposits: [ResellerDeposit]
    let onAddDeposit: () -> Void
    @State private var section = 0

    public var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $section) {
                Text("Orders (\(orders.count))").tag(0)
                Text("Deposits (\(deposits.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(16)

            if section == 0 {
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
                }
            } else {
                List(deposits) { dep in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("$\(String(format: "%.2f", dep.amountUsd)) via \(dep.gateway)")
                                .fontWeight(.medium)
                            Text(dep.createdAt.prefix(10))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(dep.status)
                            .font(.caption2)
                            .foregroundColor(dep.status == "PAID" ? .green : .orange)
                    }
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
    let balance: Double
    let onCompleted: () -> Void

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
                if selectedPlanId.isEmpty, let f = plans.first { selectedPlanId = f.id }
            }
        }
    }

    private func handleCreateOrder() {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                _ = try await ApiClient.shared.createResellerOrder(customerEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), planId: selectedPlanId)
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
    @Environment(\.dismiss) var dismiss
    @State private var detail: ResellerCustomerDetail?
    @State private var newPasswordInput = ""
    @State private var generatedPasswordResult: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?

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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(s.planName).fontWeight(.medium)
                                Text("Expires: \(s.expiryDate.prefix(10))").font(.caption).foregroundColor(.secondary)
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
