# PENDING HUMAN DECISIONS (Sprint 0.1.2)

This file collects decisions that require human input or business/vendor context.

## Backend / deployment
- Decide where the entitlements backend will live:
  - local dev only (current FastAPI stub)
  - production hosting (domain, TLS, auth)
- Decide auth model:
  - email/password
  - OAuth/Apple/Google
  - device-bound account (not recommended)

## Payments (Lite -> Angel)
- Choose IAP provider:
  - RevenueCat (recommended) vs direct StoreKit/BillingClient
- Product types and pricing:
  - subscription vs one-time unlock
- Restore purchases UX requirements

## Identity verification vendor
- Select vendor: **Onfido vs Veriff vs Jumio**
- Billing model preference: pay-per-successful-verification
- Required geos / doc types / KYC scope

## Biometric hardware SDKs
- Confirm iOS SDK packaging availability (`.xcframework`) for chosen iris/palm vein hardware.
- Licensing constraints (offline, redistribution, per-device fees).

## Networking
- Physical device testing requires replacing emulator base URL `10.0.2.2` with LAN IP or public domain.
  - Current location: `app/src/main/java/com/example/vaultguard/tier/EntitlementsConfig.kt`

