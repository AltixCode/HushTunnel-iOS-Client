# HushTunnel — iOS App Store & TestFlight Deployment Guide

This repository includes fully automated GitHub Actions CI/CD workflows (`.github/workflows/ios-release.yml`) and Fastlane automation (`fastlane/Fastfile`).

---

## 1. Required GitHub Repository Secrets

Go to **GitHub Repo $\rightarrow$ Settings $\rightarrow$ Secrets and variables $\rightarrow$ Actions** and configure the following secrets:

| Secret Name | Description | Where to Obtain |
|---|---|---|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution Certificate (`.p12` file) | Apple Developer Portal $\rightarrow$ Certificates $\rightarrow$ Export from Keychain as `.p12` $\rightarrow$ `base64 -i cert.p12 \| pbcopy` |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` certificate | Password you entered when exporting `.p12` |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store Provisioning Profile (`.mobileprovision`) | Apple Developer Portal $\rightarrow$ Profiles $\rightarrow$ Download profile $\rightarrow$ `base64 -i profile.mobileprovision \| pbcopy` |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID (e.g., `2X9R4HXF34`) | App Store Connect $\rightarrow$ Users and Access $\rightarrow$ Integrations $\rightarrow$ App Store Connect API |
| `APP_STORE_CONNECT_API_KEY_ISSUER` | App Store Connect Issuer ID (UUID format) | App Store Connect $\rightarrow$ Users and Access $\rightarrow$ Integrations $\rightarrow$ App Store Connect API |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Content of the `.p8` private key file | Downloaded from App Store Connect when creating the API key |

---

## 2. Triggering Builds and Releases

### A. Automatic TestFlight & Release via Tag:
```bash
git tag v1.0.0
git push origin v1.0.0
```
*Triggers the GitHub Action, archives the project, signs the `.ipa`, uploads to TestFlight/App Store Connect, and creates a GitHub Release with the standalone `.ipa` attached.*

### B. Manual Dispatch:
1. Go to **Actions** tab on GitHub.
2. Select **`iOS Build & App Store Release`**.
3. Click **Run workflow** and set `upload_to_app_store` to `true`.

### C. Local Fastlane:
```bash
cd /Users/atamohammadi/Dev/vpn-ios-client
bundle exec fastlane ios beta    # Uploads to TestFlight
bundle exec fastlane ios release # Uploads to App Store
```
