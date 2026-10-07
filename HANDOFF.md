⚠️ **2026-08-31: read `/Users/atamohammadi/Dev/vpn/HANDOFF.md` FIRST** — it has
the current session status (the Connect/Disconnect button was just rewired
from a complete UI mock to real `ExtensionProfile` calls, on the `dev`
branch, real-device-unverified), a live P1 bug report from the Android app
(same underlying VPN-connectivity class of issue — check if iOS shares it),
and the full new-feature backlog: reseller password choice + copy-confirm
flow, clickable customer detail pages (this app already has
`ResellerCustomerDetailSheetView` — check its current coverage before
rebuilding), **sub-reseller management — this app's `ResellerHomeView` tab
list has no sub-reseller tab, same gap as Android**, Farsi localization
gaps, currency localization. This file below is the older architecture/
feature reference, still accurate for background, but the ecosystem
HANDOFF.md is where the current task list lives.

# HushTunnel iOS Client — Architecture & Handoff Specification

This is the comprehensive handoff and architectural specification for the **HushTunnel iOS Client** (`~/Dev/vpn-ios-client`).

---

## 1. Project Overview & Base

- **Base Repository**: Forked from [`SagerNet/sing-box-for-apple`](https://github.com/SagerNet/sing-box-for-apple).
- **Core Technologies**:
  - Swift 5.10+ / SwiftUI
  - NetworkExtension framework (`NEPacketTunnelProvider`)
  - Go-compiled `Libbox.xcframework` (`sing-box` universal proxy core supporting VLESS REALITY, vision flow, gRPC, and reality certificates).
- **Backend API**: `https://vpn-billing-dashboard.vercel.app` (Next.js App Router).

---

## 2. Directory Structure

```
vpn-ios-client/
├── ApplicationLibrary/
│   ├── HushTunnel/
│   │   ├── Core/
│   │   │   ├── BrandConfig.swift        # App identity, URLs, AppGroup
│   │   │   ├── AuthStore.swift          # Session persistence (token, email, role)
│   │   │   └── LanguageManager.swift    # Multi-language manager & RTL switcher
│   │   ├── Models/
│   │   │   └── BrandModels.swift        # Codable data models (Consumer & Reseller)
│   │   ├── Network/
│   │   │   └── ApiClient.swift          # Modern async/await REST client
│   │   └── Views/
│   │       ├── RootView.swift           # Main auth & role dispatcher
│   │       ├── AuthView.swift           # Login & Sign up with language switcher
│   │       ├── UserHomeView.swift       # Consumer dashboard (Connect, usage, renew)
│   │       └── ResellerHomeView.swift   # Reseller 5-tab portal (VPN, Customers, Subscriptions, Orders, Deposits)
├── SFI/
│   ├── Application.swift                # App entry point (launches RootView)
│   └── Info.plist
├── Extension/                           # NetworkExtension packet tunnel provider
└── HushTunnel.xcodeproj
```

---

## 3. Features & Parity Matrix

### A. Authentication & Language
- **Login / Sign Up**: Email & Password validation, error banners, JWT Bearer storage in `AuthStore`.
- **Localization**: Built-in 5 languages with instant switching and Persian RTL layout:
  - English (`en`)
  - Persian (`fa` / RTL)
  - Russian (`ru`)
  - Chinese (`zh`)
  - Turkish (`tr`)

### B. Consumer (USER) Dashboard
- **Connect / Disconnect Button**: Large animated status button with pulsating indicator rings.
- **Active Subscriptions**:
  - Plan name & expiration date.
  - Live data usage progress bar (used / total data).
  - 1-Click Renew modal with gateway selection (Cryptomus, NOWPayments, Revolut, Manual).
- **Plan Discovery & Checkout**: Full package selection modal for new subscriptions.
- **Order History**: Real-time order ledger with payment status badges (`PAID`, `PENDING`).

### C. Reseller Portal (`role == "RESELLER"`)
- **Tab 0 (My VPN)**:
  - Connect / Disconnect widget for the reseller's personal VPN.
  - If no personal subscription exists: "Create My Personal VPN" action that calls `/api/mobile/reseller/self-subscription` and debits wallet balance at their discounted price.
- **Tab 1 (Dashboard & Wallet)**:
  - Wallet balance display ($XX.XX), discount tier % (0% to 20%), next tier progress.
  - Deposit funds modal with gateway invoices.
  - Quick action shortcuts.
- **Tab 2 (Customers Management - Full CRUD)**:
  - Searchable customer list.
  - "Add Customer" modal (supports auto-generated or custom passwords).
  - "Customer Details" sheet showing customer's active subscriptions and order history.
  - "Change/Reset Password" dialog.
  - "Buy Plan for Customer" from wallet balance.
  - "Delete Customer" action (revokes inbounds on 3x-ui and removes user).
- **Tab 3 (Subscriptions Management)**:
  - List of all customer and personal subscriptions with live bandwidth progress bars.
  - Quick action buttons: Extend +30 Days, Enable/Disable, Reset UUID, Reset Traffic, Revoke/Delete.
- **Tab 4 (Orders & Deposits)**:
  - Live customer order ledger and deposit payment invoices.

---

## 4. Building & Running in Xcode

1. Open `HushTunnel.xcodeproj` in Xcode on macOS.
2. Ensure your Apple Developer Signing Team is selected under **Signing & Capabilities** for targets `SFI` and `Extension`.
3. Build & run on an iOS Device or Simulator (iOS 16+).


### App Store External Purchase Compliance & Password Management
- **In-App Store Concealment**: Direct in-app purchase buttons hidden in mobile clients to comply with Apple & Google fee guidelines.
- **External Web Store Notice**: Displaying localized notice card linking to `https://www.hushtunnel.com` with support for Cryptocurrency (USDT, BTC, etc.) and Credit Cards.
- **Reseller Renewal Info**: Instructions for users who acquired subscriptions via resellers to contact their provider or renew online.
- **Self Password Change**: Endpoints and UI implemented across:
  - Mobile API: `POST /api/mobile/account/password` (bcrypt validation & update).
  - iOS App: `ChangePasswordSheetView` in consumer and reseller portals.
  - Android App: `ChangePasswordDialog` in consumer and reseller portals.
  - Web Dashboard: `ChangePasswordDialog` in `/dashboard` and `/reseller`.
  - Admin Panel: `AdminProfileForm` in `/admin/settings` allowing SuperAdmin to update Email and Password.
