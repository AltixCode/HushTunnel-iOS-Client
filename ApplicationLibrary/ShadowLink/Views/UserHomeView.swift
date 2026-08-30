import SwiftUI

public struct UserHomeView: View {
    @ObservedObject var authStore = AuthStore.shared
    @ObservedObject var lang = LanguageManager.shared

    @State private var meResult: MeResult?
    @State private var plans: [PlanInfo] = []
    @State private var gateways = GatewayInfo()
    @State private var isLoading = false
    @State private var isConnected = false
    @State private var isConnecting = false
    @State private var errorMessage: String?

    @State private var showBuyPlanSheet = false
    @State private var showRenewSheet = false
    @State private var showOrdersSheet = false
    @State private var showLanguagePicker = false
    @State private var selectedSubscriptionForRenew: SubscriptionInfo?

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Status & Connect Section
                        VStack(spacing: 24) {
                            // Circular Connect Button
                            Button(action: toggleConnection) {
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

                            // Status Label
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(isConnected ? Color.green : (isConnecting ? Color.orange : Color.gray))
                                    .frame(width: 10, height: 10)

                                Text(isConnecting ? lang.tr("vpn.connecting") : (isConnected ? lang.tr("vpn.connected") : lang.tr("vpn.disconnected")))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(24)
                        .padding(.horizontal, 16)

                        // Subscriptions Section
                        if let subs = meResult?.subscriptions, !subs.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(lang.tr("vpn.activePlan"))
                                    .font(.headline)
                                    .padding(.horizontal, 20)

                                ForEach(subs) { sub in
                                    SubscriptionCardView(sub: sub, onRenew: {
                                        selectedSubscriptionForRenew = sub
                                        showRenewSheet = true
                                    })
                                    .padding(.horizontal, 16)
                                }
                            }
                        } else if !isLoading {
                            // No subscription empty state
                            VStack(spacing: 14) {
                                Image(systemName: "shield.slash")
                                    .font(.system(size: 44))
                                    .foregroundColor(.orange)

                                Text(lang.tr("vpn.noSub"))
                                    .font(.headline)

                                Text(lang.tr("vpn.noSubDesc"))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)

                                Button {
                                    showBuyPlanSheet = true
                                } label: {
                                    Text(lang.tr("vpn.buyPlan"))
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                .padding(.top, 6)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(Color(uiColor: .systemBackground))
                            .cornerRadius(20)
                            .padding(.horizontal, 16)
                        }

                        // Quick Actions
                        HStack(spacing: 12) {
                            Button {
                                showBuyPlanSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "cart.fill")
                                    Text(lang.tr("vpn.buyPlan"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .cornerRadius(14)
                            }

                            Button {
                                showOrdersSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "list.bullet.rectangle")
                                    Text(lang.tr("orders.title"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .cornerRadius(14)
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 32)
                    }
                }
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
                    Button {
                        authStore.logout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .confirmationDialog(lang.tr("common.language"), isPresented: $showLanguagePicker, titleVisibility: .visible) {
                ForEach(AppLanguage.allCases) { l in
                    Button(l.displayName) {
                        lang.setLanguage(l)
                    }
                }
                Button(lang.tr("common.cancel"), role: .cancel) {}
            }
            .sheet(isPresented: $showBuyPlanSheet) {
                PlanCheckoutSheetView(plans: plans, gateways: gateways, subscriptionId: nil, onCompleted: refreshData)
            }
            .sheet(isPresented: $showRenewSheet) {
                PlanCheckoutSheetView(plans: plans, gateways: gateways, subscriptionId: selectedSubscriptionForRenew?.id, onCompleted: refreshData)
            }
            .sheet(isPresented: $showOrdersSheet) {
                OrdersListView()
            }
            .onAppear(perform: refreshData)
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

    private func refreshData() {
        isLoading = true
        Task {
            do {
                async let meTask = ApiClient.shared.me()
                async let plansTask = ApiClient.shared.plans()
                async let gatewaysTask = ApiClient.shared.gateways()

                let (meRes, plansRes, gatewaysRes) = try await (meTask, plansTask, gatewaysTask)

                await MainActor.run {
                    self.meResult = meRes
                    self.plans = plansRes
                    self.gateways = gatewaysRes
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
}

// MARK: - Subscription Card Component

public struct SubscriptionCardView: View {
    let sub: SubscriptionInfo
    let onRenew: () -> Void
    @ObservedObject var lang = LanguageManager.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sub.planName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(formattedExpiry(sub.expiryDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onRenew) {
                    Text(lang.tr("vpn.renew"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                }
            }

            // Usage Bar
            if sub.totalBytes > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    let pct = min(1.0, Double(sub.usedBytes) / Double(sub.totalBytes))
                    ProgressView(value: pct)
                        .tint(pct > 0.9 ? .red : .accentColor)

                    HStack {
                        Text("\(formatBytes(sub.usedBytes)) / \(formatBytes(sub.totalBytes))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(pct * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func formattedExpiry(_ dateString: String) -> String {
        return "Expires: \(dateString.prefix(10))"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Plan Checkout Sheet

public struct PlanCheckoutSheetView: View {
    let plans: [PlanInfo]
    let gateways: GatewayInfo
    let subscriptionId: String?
    let onCompleted: () -> Void

    @Environment(\.dismiss) var dismiss
    @ObservedObject var lang = LanguageManager.shared

    @State private var selectedPlanId: String = ""
    @State private var selectedGateway = "MANUAL"
    @State private var isProcessing = false
    @State private var errorMessage: String?

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Choose Duration / Plan")) {
                    ForEach(plans) { plan in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.name)
                                    .fontWeight(.medium)
                                Text(plan.description ?? "\(plan.durationDays) days access")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("$\(String(format: "%.2f", plan.priceUsd))")
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)

                            if selectedPlanId == plan.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .padding(.leading, 8)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPlanId = plan.id
                        }
                    }
                }

                Section(header: Text("Payment Method")) {
                    if gateways.cryptomus {
                        HStack {
                            Text("Cryptocurrency (Cryptomus)")
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
                        Text("Manual / Admin Confirmation")
                        Spacer()
                        if selectedGateway == "MANUAL" { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedGateway = "MANUAL" }
                }

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundColor(.red).font(.caption)
                    }
                }

                Section {
                    Button(action: handleCheckout) {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView().padding(.trailing, 8)
                            }
                            Text(subscriptionId != nil ? lang.tr("vpn.renew") : lang.tr("vpn.buyPlan"))
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(selectedPlanId.isEmpty || isProcessing)
                }
            }
            .navigationTitle(subscriptionId != nil ? lang.tr("vpn.renew") : lang.tr("vpn.buyPlan"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.tr("common.cancel")) { dismiss() }
                }
            }
            .onAppear {
                if selectedPlanId.isEmpty, let first = plans.first {
                    selectedPlanId = first.id
                }
            }
        }
    }

    private func handleCheckout() {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let res = try await ApiClient.shared.checkout(
                    planId: selectedPlanId,
                    gateway: selectedGateway,
                    subscriptionId: subscriptionId
                )

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

// MARK: - Orders List Sheet

public struct OrdersListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lang = LanguageManager.shared
    @State private var orders: [OrderItem] = []
    @State private var isLoading = false

    public var body: some View {
        NavigationView {
            List(orders) { order in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.planName)
                            .fontWeight(.medium)
                        Text(order.createdAt.prefix(10))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(String(format: "%.2f", order.amountUsd))")
                            .fontWeight(.bold)
                        Text(order.status)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(order.status == "PAID" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .foregroundColor(order.status == "PAID" ? .green : .orange)
                            .cornerRadius(4)
                    }
                }
            }
            .navigationTitle(lang.tr("orders.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.tr("common.done")) { dismiss() }
                }
            }
            .onAppear {
                Task {
                    isLoading = true
                    if let list = try? await ApiClient.shared.orders() {
                        await MainActor.run { orders = list }
                    }
                    isLoading = false
                }
            }
        }
    }
}
