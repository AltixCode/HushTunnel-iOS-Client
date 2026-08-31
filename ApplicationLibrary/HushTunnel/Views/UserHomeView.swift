import SwiftUI

public struct UserHomeView: View {
    @ObservedObject var authStore = AuthStore.shared
    @ObservedObject var lang = LanguageManager.shared

    @State private var meResult: MeResult?
    @State private var isLoading = false
    @State private var isConnected = false
    @State private var isConnecting = false
    @State private var errorMessage: String?

    @State private var showOrdersSheet = false
    @State private var showLanguagePicker = false
    @State private var showChangePasswordSheet = false

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
                                    SubscriptionCardView(sub: sub)
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
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(Color(uiColor: .systemBackground))
                            .cornerRadius(20)
                            .padding(.horizontal, 16)
                        }

                        // Official Web Store & Renewal Notice Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: "globe.americas.fill")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                Text(lang.tr("web.storeNotice"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }

                            Text(lang.tr("web.storeDesc"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Link(destination: URL(string: "https://www.hushtunnel.com")!) {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("https://www.hushtunnel.com")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "safari")
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .cornerRadius(12)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                        .padding(.top, 2)
                                    Text(lang.tr("web.paymentMethods"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.top, 2)
                                    Text(lang.tr("web.resellerNotice"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(20)
                        .padding(.horizontal, 16)

                        // Quick Actions (Order History & Password)
                        HStack(spacing: 12) {
                            Button {
                                showChangePasswordSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text(lang.tr("account.changePassword"))
                                }
                                .font(.subheadline)
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
                                .font(.subheadline)
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
                    HStack(spacing: 16) {
                        Button {
                            showChangePasswordSheet = true
                        } label: {
                            Image(systemName: "lock.rotation")
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
                let meRes = try await ApiClient.shared.me()
                await MainActor.run {
                    self.meResult = meRes
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

                Link(destination: URL(string: "https://www.hushtunnel.com")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                        Text(lang.tr("vpn.renew"))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
                }
            }

            // Usage Bar
            VStack(alignment: .leading, spacing: 4) {
                if sub.totalBytes > 0 {
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
                } else {
                    HStack {
                        Text("\(lang.tr("vpn.trafficUsed")): \(formatBytes(sub.usedBytes))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Unlimited")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func formattedExpiry(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }

        guard let exp = date else { return "\(lang.tr("vpn.expires")): \(dateString)" }

        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: Date(), to: exp).day ?? 0
        if days < 0 {
            return "Expired"
        }
        let outFormat = DateFormatter()
        outFormat.dateStyle = .medium
        return "\(lang.tr("vpn.expires")): \(outFormat.string(from: exp)) (\(String(format: lang.tr("vpn.daysRemaining"), max(0, days))))"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Orders List View

public struct OrdersListView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var lang = LanguageManager.shared
    @State private var orders: [OrderItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    VStack(spacing: 8) {
                        Text("Failed to load orders")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if orders.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No orders found")
                            .font(.headline)
                    }
                } else {
                    List(orders) { order in
                        OrderRowView(order: order)
                    }
                }
            }
            .environment(\.layoutDirection, lang.layoutDirection)
            .navigationTitle(lang.tr("orders.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lang.tr("common.cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear(perform: loadOrders)
        }
    }

    private func loadOrders() {
        Task {
            do {
                let ordersRes = try await ApiClient.shared.orders()
                await MainActor.run {
                    self.orders = ordersRes
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

public struct OrderRowView: View {
    let order: OrderItem

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(order.planName)
                    .font(.headline)
                Spacer()
                Text(String(format: "$%.2f", order.amountUsd))
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            HStack {
                Text(order.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(order.status).opacity(0.15))
                    .foregroundColor(statusColor(order.status))
                    .cornerRadius(6)

                Spacer()

                Text(order.gateway)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "PAID", "COMPLETED", "ACTIVE": return .green
        case "PENDING": return .orange
        default: return .gray
        }
    }
}
