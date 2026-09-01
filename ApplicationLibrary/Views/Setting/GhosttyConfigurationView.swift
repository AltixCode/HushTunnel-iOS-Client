#if !os(tvOS) && canImport(GhosttyTerminal)
    import Library
    import SwiftUI

    public struct GhosttyConfigurationView: View {
        private static let lightDefaultTheme = "Alabaster"
        private static let darkDefaultTheme = "Afterglow"

        @State private var isLoading = true
        @State private var lightPickerTheme: String = lightDefaultTheme
        @State private var lightCustomEnabled: Bool = false
        @State private var darkPickerTheme: String = darkDefaultTheme
        @State private var darkCustomEnabled: Bool = false
        @State private var fontFollowTheme: Bool = true
        @State private var fontFamily: String = ""
        @State private var fontSize: Double = 0

        public init() {}

        public var body: some View {
            FormView {
                if !isLoading {
                    schemeSection(
                        header: "Light Configuration",
                        isDark: false,
                        pickerTheme: $lightPickerTheme,
                        customEnabled: $lightCustomEnabled,
                        themePreference: SharedPreferences.tailscaleSSHGhosttyLightTheme
                    )
                    schemeSection(
                        header: "Dark Configuration",
                        isDark: true,
                        pickerTheme: $darkPickerTheme,
                        customEnabled: $darkCustomEnabled,
                        themePreference: SharedPreferences.tailscaleSSHGhosttyDarkTheme
                    )
                    fontSection()
                }
            }
            .navigationTitle("Ghostty Configuration")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                reload()
            }
        }

        private func fontSection() -> some View {
            Section(header: Text("Font Configuration")) {
                Toggle("Follow Theme", isOn: $fontFollowTheme)
                    .onChangeCompat(of: fontFollowTheme) { newValue in
                        Task {
                            await SharedPreferences.tailscaleSSHTerminalFontFollowTheme.set(newValue)
                        }
                    }
                if !fontFollowTheme {
                    TextField("Font Family", text: $fontFamily)
                        .onChangeCompat(of: fontFamily) { newValue in
                            Task {
                                await SharedPreferences.tailscaleSSHTerminalFontFamily.set(newValue)
                            }
                        }
                    TextField("Font Size", value: $fontSize, formatter: NumberFormatter())
                        .onChangeCompat(of: fontSize) { newValue in
                            Task {
                                await SharedPreferences.tailscaleSSHTerminalFontSize.set(newValue)
                            }
                        }
                }
            }
        }

        private func schemeSection(
            header: String,
            isDark: Bool,
            pickerTheme: Binding<String>,
            customEnabled: Binding<Bool>,
            themePreference: PreferenceKey<String>
        ) -> some View {
            Section(header: Text(header)) {
                Toggle("Custom Configuration", isOn: customEnabled)
                    .onChangeCompat(of: customEnabled.wrappedValue) { newValue in
                        Task {
                            if !newValue {
                                await themePreference.set("")
                            }
                            reload()
                        }
                    }
                if customEnabled.wrappedValue {
                    FormNavigationLink {
                        EditGhosttyConfigView(scheme: isDark ? .dark : .light)
                    } label: {
                        Text("Edit Configuration")
                    }
                } else {
                    themePickerLink(
                        isDark: isDark,
                        pickerTheme: pickerTheme,
                        themePreference: themePreference
                    )
                }
            }
        }

        private func themePickerLink(
            isDark: Bool,
            pickerTheme: Binding<String>,
            themePreference: PreferenceKey<String>
        ) -> some View {
            FormNavigationLink {
                ThemePickerView(
                    scheme: isDark ? .dark : .light,
                    currentName: pickerTheme.wrappedValue
                ) { newTheme in
                    pickerTheme.wrappedValue = newTheme
                    Task {
                        await themePreference.set(newTheme)
                    }
                }
            } label: {
                Text("Theme: \(pickerTheme.wrappedValue)")
            }
        }

        private func reload() {
            let lightStored = SharedPreferences.tailscaleSSHGhosttyLightTheme.getBlocking()
            if lightStored.isEmpty {
                lightCustomEnabled = true
                lightPickerTheme = Self.lightDefaultTheme
            } else {
                lightCustomEnabled = false
                lightPickerTheme = lightStored
            }
            let darkStored = SharedPreferences.tailscaleSSHGhosttyDarkTheme.getBlocking()
            if darkStored.isEmpty {
                darkCustomEnabled = true
                darkPickerTheme = Self.darkDefaultTheme
            } else {
                darkCustomEnabled = false
                darkPickerTheme = darkStored
            }
            fontFollowTheme = SharedPreferences.tailscaleSSHTerminalFontFollowTheme.getBlocking()
            fontFamily = SharedPreferences.tailscaleSSHTerminalFontFamily.getBlocking()
            fontSize = SharedPreferences.tailscaleSSHTerminalFontSize.getBlocking()
            isLoading = false
        }
    }
#else
    import SwiftUI

    public struct GhosttyConfigurationView: View {
        public init() {}
        public var body: some View {
            EmptyView()
        }
    }
#endif
