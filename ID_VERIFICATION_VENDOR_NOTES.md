# ID Verification Vendor Notes (Sprint 0.1.2 Prep)

## Goal
After a successful purchase (Lite → Angel), we must trigger **identity verification** automatically (cost covered by the purchase), then activate `ANGEL` entitlements on success.

## Backend stub (current)
- `POST /api/verify-identity`
  - Accepts a mock token and returns `{ ok: true, status: "VERIFIED" }`
  - Stores a record in SQLite table `identity_verifications`

## When integrating a real vendor (Onfido/Veriff/Jumio)
You will need to configure:
- **API keys** (server-side only; never ship secret keys in app)
- **Webhook endpoints** for asynchronous status updates
- **Verification session creation** endpoint (server → vendor)
- **User flow**:
  1) Purchase confirmed (IAP receipt validated)
  2) Backend creates verification session with vendor
  3) App launches vendor SDK / web flow with session token
  4) Vendor posts webhook status updates (e.g., verified/rejected)
  5) Backend updates `identity_verified` status and flips entitlements to `ANGEL`

## Data model suggestions
- `IdentityVerification` fields:
  - `userId`
  - `vendor`
  - `status` (PENDING / VERIFIED / REJECTED / ERROR)
  - `createdAt`, `updatedAt`
  - `vendorSessionId`
  - `resultPayloadRedacted` (optional)

## Security notes
- Store only what is required (minimization).
- Never store raw document images unless required; if stored, encrypt at rest and define retention.
- Ensure audit logs are metadata-only (no PII leakage).

