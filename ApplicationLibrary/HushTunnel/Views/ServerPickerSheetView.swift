import SwiftUI

public struct ServerPickerSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var lang = LanguageManager.shared

    let servers: [ServerNodeItem]
    let selectedServer: ServerNodeItem?
    let onSelect: (ServerNodeItem) -> Void

    @State private var searchText = ""

    public init(
        servers: [ServerNodeItem],
        selectedServer: ServerNodeItem?,
        onSelect: @escaping (ServerNodeItem) -> Void
    ) {
        self.servers = servers
        self.selectedServer = selectedServer
        self.onSelect = onSelect
    }

    private var filteredServers: [ServerNodeItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return servers
        }
        return servers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.countryCode.localizedCaseInsensitiveContains(searchText) ||
            ($0.city?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search location or country...", text: $searchText)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if filteredServers.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "globe.badge.chevron.backward")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No matching server locations")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredServers) { server in
                            let isSelected = (server.id == selectedServer?.id) || (selectedServer == nil && server.isDefault == true)

                            Button {
                                onSelect(server)
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    Text(server.flag)
                                        .font(.system(size: 28))

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(server.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            if server.isDefault == true {
                                                Text("AUTO")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .foregroundColor(.accentColor)
                                                    .cornerRadius(4)
                                            }
                                        }

                                        Text("\(server.city ?? server.countryCode) · VLESS-Reality")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.accentColor)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.title3)
                                            .foregroundColor(.secondary.opacity(0.4))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lang.tr("common.done")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
