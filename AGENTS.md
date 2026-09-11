# HushTunnel iOS Client Guidelines

## 1. Brand Identity & Master Guide
- **Product Name**: Strictly **HushTunnel** (or **Hush Tunnel**), never with "VPN" appended.
- **App Store Bundle ID**: `com.hushtunnel.ios` (App Store Connect ID: `6807551411`).
- **Master Ecosystem Guide**: See `../AGENTS.md` for overall multi-repo architecture, RevenueCat mappings, and store procedures.
- **In-App Subscriptions**: Powered by RevenueCat SDK 5.88.0 (`InAppPurchaseSheetView.swift` & `RevenueCatManager.swift`). StoreKit product IDs: `hushtunnel_1month` (1 month, $3), `hushtunnel_3_months` (3 months, $7), `hushtunnel_6_months` (6 months, $12), and `hushtunnel_12_months` (1 year, $20). Consumable wallet products: `hushtunnel_funds_5` through `hushtunnel_funds_100`.

## 2. Dependencies & Build Compatibility
- Pinned `GRDB.swift` to `7.8.0` in `sing-box.xcodeproj` and `Package.resolved` for Swift 6.0/macOS 15 toolchain compatibility.
- `Libbox.xcframework` is compiled automatically via `sagernet/gomobile` and cached in CI (`.github/workflows/ios-release.yml`).

## 3. Localization
- Multi-language support (English, Persian / RTL, Russian, Chinese, Turkish).

## 4. Test Suite Execution
- **Run iOS E2E Automated Suite** (builds for Simulator, installs, launches,
  screenshots — real Xcode toolchain required):
  ```bash
  bash scripts/test-ios-e2e.sh
  ```
- **Real build verification is available in this environment** — don't assume
  otherwise. `xcodebuild -project sing-box.xcodeproj -scheme SFI -destination
  'generic/platform=iOS Simulator' build` (with
  `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`) actually
  compiles the whole app and catches real errors; used to verify the
  real-VPN-connect wiring below before it was committed. The `SFM` (macOS)
  scheme currently fails on an unrelated `SwiftLintPlugin`/SourceKit issue
  when built headlessly (`Fatal error: Loading sourcekitdInProc.framework...
  failed`) — pre-existing, not caused by app code, only blocks the macOS
  target.

## 5. Standing Development Requirements

- **The VPN connect/disconnect button is now real**, not a UI mock. Before
  2026-08-31, `UserHomeView`/`ResellerHomeView`'s `toggleConnection()` just
  flipped local `@State` booleans on a timer — the button looked functional
  but never touched the real `ExtensionProfile`/`NetworkExtension`, on either
  the plain-user or reseller screen. Now:
  - `ProvisionHelper.provisionSubscription(subscriptionUrl:)`
    (`HushTunnel/Core/ProvisionHelper.swift`) creates/updates a `Profile`
    (`type: .remote`, `remoteURL: "<subscriptionUrl>?format=sing-box"`) using
    sing-box's own real remote-profile pipeline (same pattern as
    `NewProfileViewModel`'s `.remote` branch) and selects it. Called from
    `refreshData()`/`refreshAll()` whenever an active subscription exists.
  - `ConnectCircleButton`/`ConnectStatusLabel`
    (`HushTunnel/Views/ConnectCircleButton.swift`) call the real
    `ExtensionProfile.start()`/`.stop()` and observe `.status`, taking the
    profile as a direct `@ObservedObject` parameter — **not** via
    `@EnvironmentObject` reading `environments.extensionProfile?.status`,
    which would silently never update the UI (a `@Published` property on an
    object *held by* another `ObservableObject` doesn't propagate through the
    outer object's `objectWillChange`). `StartStopButton` already solves this
    the same way; follow that pattern for any similar wiring.
  - Both home views now call `await environments.reload()` in a `.task` —
    `RootView` bypasses `MainView`/`DashboardView` (the stock app's own root),
    which is where `reload()`/`postReload()` normally gets called, so without
    this `environments.extensionProfile` would just stay `nil` forever on the
    branded screens.
  - The backend's default subscription format (base64 `vless://` links, for
    v2ray-family clients) does **not** validate as a sing-box config —
    `?format=sing-box` on the same URL returns a complete document instead
    (`buildSingBoxConfig` in the web repo's `lib/singbox-config.ts`, schema
    verified against the real `sing-box check` CLI). Don't point a `Profile`
    at the plain subscription URL.
  - **Not verified on a real device.** Network Extension / VPN entitlements
    are known to behave differently (or not work at all) in the iOS
    Simulator vs. a physical device. Build success + simulator launch +
    real API calls succeeding (verified 2026-08-31) is strong but not
    complete evidence — actually connecting and passing traffic through the
    tunnel needs a real-device pass before shipping.
  - Server switching (`ServerPickerSheetView`'s `onSelect`) only changes which
    server the picker card displays — it does not yet re-route the live
    tunnel to that specific node. A real per-server switch means rewriting
    the profile's `route.final` to the selected server's tag and calling
    `updateRemoteProfile()`/`restart()`. Not wired.
- **Every user-facing string must exist in all 5 supported locales** (en
  baseline, fa/RTL, ru, zh, tr) via `LanguageManager`/`lang.tr(...)` — never
  a hardcoded literal for anything a user reads.
