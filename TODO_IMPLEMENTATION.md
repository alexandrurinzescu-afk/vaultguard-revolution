# VAULTGUARD — TODO IMPLEMENTATION (3-tier architecture)

This file tracks the new strategic plan: **Angel Lite → Angel → Revolution**.

## A) Feature flags / entitlements system
- [ ] Define entitlement model:
  - `isLiteMode`
  - `isAngelActivated`
  - `isRevolutionActivated`
- [ ] Backend contract: endpoint to fetch entitlements at login/refresh (signed response).
- [ ] Client storage rules:
  - store last entitlements + issuedAt
  - deny-by-default if missing/invalid (except LITE onboarding)
- [ ] Implement `isFeatureEnabled(feature)` mapping to entitlements.

## B) Onboarding + payment gate (Lite → Angel)
- [ ] Update onboarding copy to explain 3 levels clearly.
- [ ] IAP provider decision (RevenueCat recommended for cross-store):
  - products, restore purchases, receipt validation.
- [ ] Critical: trigger ID verification ONLY after IAP success (cost coverage).
- [ ] Add activation flow:
  - IAP success → start verification → backend marks `isAngelActivated=true`.

## C) External integrations (SDKs)
- [ ] Biometric hardware SDK packaging review (Android+iOS):
  - .aar/.jar + .so (Android)
  - .xcframework (iOS)
- [ ] Implement vendor SDK behind generic interface (no vendor-specific leaking into app core).
- [ ] Identity verification vendor comparison (Onfido/Veriff/Jumio): pay-per-successful-verification.

## D) Backend + security
- [ ] Data model:
  - `UserID` ↔ `IdentityVerified` ↔ `IrisTemplate` ↔ `PalmVeinTemplate`
- [ ] Encrypt biometric templates at rest (KMS/Key management + rotation).
- [ ] Audit logs for:
  - entitlement changes
  - biometric enrollment / verification events (metadata only)
- [ ] Admin endpoints:
  - manual unlock for testing
  - breach/incident workflow (if applicable)

## E) Website upgrade (Angel → Revolution)
- [ ] Create simple landing + pricing on `vaultguardangel.com`.
- [ ] Stripe payment integration (server-side).
- [ ] Secure webhook → backend toggles `isRevolutionActivated=true`.
- [ ] In-app refresh entitlements and unlock premium UI.

