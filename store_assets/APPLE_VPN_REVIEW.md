# Apple VPN review checklist — HushTunnel

Use this checklist for the App Store Connect record for `com.hushtunnel.ios`.
Keep the answers synchronized with the in-app disclosure and the public policy.

## Required account and metadata checks

- Submit from an Apple Developer Program account enrolled as an organization.
- Keep the Network Extension entitlement approved for the app and packet-tunnel
  extension. The implementation uses `NEVPNManager`/`NETunnelProviderManager`
  and an `NEPacketTunnelProvider`.
- Privacy Policy URL: `https://www.hushtunnel.com/privacy`
- Terms URL: `https://www.hushtunnel.com/terms`
- Ensure the App Store description clearly states that secure device-level VPN
  connectivity is HushTunnel's core functionality.
- Confirm licensing and local-law requirements in every territory selected for
  sale. Provide license details in App Review Notes where a territory requires
  them.

## App Privacy answers to verify in App Store Connect

Declare the data actually collected by the submitted build and backend. At
minimum, review these categories rather than selecting “Data Not Collected”:

- Contact Info: email address — linked to the user; app functionality and
  account authentication.
- Identifiers: HushTunnel account/user ID and store transaction identifiers —
  linked to the user; app functionality, purchases, fraud prevention.
- Purchases: product, transaction, entitlement, refund, and purchase status —
  linked to the user; app functionality and accounting.
- Other Usage Data: aggregate bytes used for quota enforcement — linked to the
  account, but not capable of reconstructing browsing activity.
- Diagnostics/Security: declare any error or crash details the submitted build
  actually sends. Operational IP address, request time, app/OS version, and
  errors may be processed briefly for delivery, abuse prevention, and support.

Do not declare browsing history, DNS requests, traffic destinations, or VPN
payload content as collected because HushTunnel does not retain them. RevenueCat
is used for purchase and entitlement processing, not tracking or advertising.
Re-check RevenueCat's current privacy disclosure guidance whenever its SDK or
configuration changes.

## Suggested App Review Notes

HushTunnel is a VPN app whose core functionality is a secure device-level
tunnel. It uses Apple's Network Extension APIs (`NEVPNManager`,
`NETunnelProviderManager`, and `NEPacketTunnelProvider`). After authentication
and before the user can see purchase controls or use the VPN, the app displays
a separate VPN disclosure. The screen explains transient traffic processing,
the encrypted device-to-endpoint boundary, data retained for account/quota/
purchases/security, and that VPN traffic data is not sold, used, or disclosed
to third parties beyond processing required to provide the requested tunnel.
The user must tap **Agree and Continue**. **Not now** starts no tunnel and signs
the user out. Privacy Policy and Terms links are on that screen, registration,
and Account Settings. Permanent account deletion is available in Account
Settings; Apple subscriptions must be canceled separately through Apple's
subscription management screen.

Provide App Review with a working user account that reaches the disclosure and
has a plan available for purchase. State where **Account Settings**, **Restore
Purchases**, **Manage App Store subscription**, and **Delete Account
Permanently** are located.
